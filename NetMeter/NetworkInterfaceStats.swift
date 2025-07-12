//
//  NetworkInterfaceStats.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//
import Foundation
import SystemConfiguration
import os.log

// MARK: - Interface Statistics Errors
enum InterfaceStatsError: Error, LocalizedError {
    case failedToGetInterfaces
    case invalidInterfaceData
    case noActiveInterfaces
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .failedToGetInterfaces:
            return "Failed to retrieve network interfaces"
        case .invalidInterfaceData:
            return "Invalid network interface data"
        case .noActiveInterfaces:
            return "No active network interfaces found"
        case .permissionDenied:
            return "Permission denied accessing network interfaces"
        }
    }
}

// This struct will hold interface statistics
struct InterfaceStats: Codable, Equatable {
    var inputBytes: UInt64 = 0
    var outputBytes: UInt64 = 0
    var interfaceName: String = ""
    var ipAddress: String = ""
    var isActive: Bool = false
    var interfaceType: InterfaceType = .unknown
    
    enum InterfaceType: String, Codable, CaseIterable {
        case wifi = "Wi-Fi"
        case ethernet = "Ethernet"
        case thunderbolt = "Thunderbolt"
        case usb = "USB"
        case vpn = "VPN"
        case loopback = "Loopback"
        case unknown = "Unknown"
        
        static func fromInterfaceName(_ name: String) -> InterfaceType {
            switch name {
            case "en0":
                return .wifi
            case "en1", "en2", "en3":
                return .ethernet
            case "en4":
                return .thunderbolt
            case "en5":
                return .usb
            case "lo0":
                return .loopback
            default:
                if name.hasPrefix("utun") {
                    return .vpn
                } else if name.hasPrefix("en") {
                    return .ethernet
                } else {
                    return .unknown
                }
            }
        }
    }
}

// Class to get network interface statistics
class NetworkInterfaceStats {
    private static let logger = Logger(subsystem: "com.netmeter.app", category: "NetworkInterfaceStats")
    
    // Cache for interface descriptions to avoid repeated lookups
    private static var interfaceDescriptionCache: [String: String] = [:]
    
    // Cache for active interfaces to improve performance
    private static var activeInterfacesCache: [InterfaceStats] = []
    private static var lastCacheUpdate: Date = Date.distantPast
    private static let cacheValidityDuration: TimeInterval = 5.0 // 5 seconds
    
    private static var lastInterfaceCount: Int? = nil
    private static var lastPrimaryInterfaceName: String? = nil
    
    static func getAllInterfaces() throws -> [InterfaceStats] {
        var interfaces: [InterfaceStats] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        // Get list of all network interfaces
        guard getifaddrs(&ifaddr) == 0 else {
            logger.error("Failed to get network interfaces: \(String(cString: strerror(errno)))")
            throw InterfaceStatsError.failedToGetInterfaces
        }
        
        defer { freeifaddrs(ifaddr) }
        
        // Loop through linked list of interfaces
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            // Safely get interface name
            let name = String(cString: interface.ifa_name)
            
            // Only process link-level interfaces (AF_LINK)
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            
            var stats = InterfaceStats()
            stats.interfaceName = name
            stats.interfaceType = InterfaceStats.InterfaceType.fromInterfaceName(name)
            
            // Get traffic data safely
            if let data = interface.ifa_data {
                let networkData = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0 }
                
                stats.inputBytes = UInt64(networkData.pointee.ifi_ibytes)
                stats.outputBytes = UInt64(networkData.pointee.ifi_obytes)
                
                // Find IP address for this interface
                stats.ipAddress = getIPAddress(for: name)
                stats.isActive = !stats.ipAddress.isEmpty && stats.ipAddress != "Unknown"
                
                interfaces.append(stats)
            }
        }
        
        let count = interfaces.count
        if lastInterfaceCount != count {
            logger.debug("Found \(count) network interfaces")
            lastInterfaceCount = count
        }
        return interfaces
    }
    
    static func getIPAddress(for interfaceName: String) -> String {
        var address = "Unknown"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        // Get list of all interfaces
        guard getifaddrs(&ifaddr) == 0 else {
            logger.error("Failed to get interfaces for IP lookup: \(String(cString: strerror(errno)))")
            return address
        }
        
        defer { freeifaddrs(ifaddr) }
        
        // Loop through linked list of interfaces
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            let name = String(cString: interface.ifa_name)
            
            // Only process interfaces that match the requested name
            guard name == interfaceName else { continue }
            
            // Only look for IPv4 interfaces
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            
            // Convert interface address to a human readable string
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            )
            
            if result == 0 {
                address = String(cString: hostname)
            } else {
                logger.warning("Failed to get IP for interface \(interfaceName): \(String(cString: gai_strerror(result)))")
            }
            
            break
        }
        
        return address
    }
    
    static func getPrimaryInterface() throws -> InterfaceStats? {
        // Check cache first
        if Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration {
            return activeInterfacesCache.first
        }
        // Get all interfaces
        let allInterfaces = try getAllInterfaces()
        // Filter out loopback and non-physical interfaces
        let physicalInterfaces = allInterfaces.filter { interface in
            !interface.interfaceName.hasPrefix("lo") &&
            !interface.interfaceName.hasPrefix("utun") &&
            !interface.interfaceName.hasPrefix("awdl") &&
            !interface.interfaceName.hasPrefix("bridge")
        }
        // Pick the interface with the highest traffic
        let primaryInterface = physicalInterfaces.max(by: { ($0.inputBytes + $0.outputBytes) < ($1.inputBytes + $1.outputBytes) })
        // Update cache
        activeInterfacesCache = primaryInterface.map { [$0] } ?? []
        lastCacheUpdate = Date()
        guard let selected = primaryInterface else {
            logger.warning("No active network interfaces found")
            throw InterfaceStatsError.noActiveInterfaces
        }
        if lastPrimaryInterfaceName != selected.interfaceName {
            logger.info("Selected primary interface: \(selected.interfaceName) (\(selected.interfaceType.rawValue))")
            lastPrimaryInterfaceName = selected.interfaceName
        }
        return selected
    }
    
    private static func getInterfacePriority(_ type: InterfaceStats.InterfaceType) -> Int {
        switch type {
        case .wifi:
            return 5
        case .ethernet:
            return 4
        case .thunderbolt:
            return 3
        case .usb:
            return 2
        case .vpn:
            return 1
        case .loopback, .unknown:
            return 0
        }
    }
    
    static func getInterfaceDescription(for name: String) -> String {
        // Check cache first
        if let cachedDescription = interfaceDescriptionCache[name] {
            return cachedDescription
        }
        
        let description: String
        
        switch name {
        case "en0":
            description = "Wi-Fi"
        case "en1":
            description = "Ethernet"
        case "en2":
            description = "Ethernet 2"
        case "en3":
            description = "Ethernet 3"
        case "en4":
            description = "Thunderbolt Ethernet"
        case "en5":
            description = "USB Ethernet"
        case "lo0":
            description = "Loopback"
        default:
            if name.hasPrefix("en") {
                description = "Network Interface"
            } else if name.hasPrefix("utun") {
                description = "VPN Tunnel"
            } else if name.hasPrefix("awdl") {
                description = "Apple Wireless Direct Link"
            } else if name.hasPrefix("bridge") {
                description = "Bridge Interface"
            } else {
                description = name
            }
        }
        
        // Cache the result
        interfaceDescriptionCache[name] = description
        return description
    }
    
    // MARK: - Utility Methods
    
    static func clearCache() {
        interfaceDescriptionCache.removeAll()
        activeInterfacesCache.removeAll()
        lastCacheUpdate = Date.distantPast
        logger.debug("Interface cache cleared")
    }
    
    static func getInterfaceStats() -> [String: Any] {
        do {
            let interfaces = try getAllInterfaces()
            let activeCount = interfaces.filter { $0.isActive }.count
            let totalCount = interfaces.count
            
            return [
                "totalInterfaces": totalCount,
                "activeInterfaces": activeCount,
                "interfaces": interfaces.map { [
                    "name": $0.interfaceName,
                    "type": $0.interfaceType.rawValue,
                    "ip": $0.ipAddress,
                    "active": $0.isActive,
                    "inputBytes": $0.inputBytes,
                    "outputBytes": $0.outputBytes
                ] }
            ]
        } catch {
            logger.error("Failed to get interface stats: \(error.localizedDescription)")
            return ["error": error.localizedDescription]
        }
    }
    
    static func validateInterface(_ interface: InterfaceStats) -> Bool {
        // Basic validation
        guard !interface.interfaceName.isEmpty else { return false }
        guard interface.inputBytes >= 0 && interface.outputBytes >= 0 else { return false }
        
        // Check for reasonable byte values (not impossibly large)
        let maxReasonableBytes: UInt64 = 1_000_000_000_000_000 // 1 PB
        guard interface.inputBytes < maxReasonableBytes && interface.outputBytes < maxReasonableBytes else {
            logger.warning("Interface \(interface.interfaceName) has suspiciously large byte values")
            return false
        }
        
        return true
    }
}
