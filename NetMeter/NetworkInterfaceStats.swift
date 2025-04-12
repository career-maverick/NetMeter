//
//  NetworkInterfaceStats.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//
import Foundation
import SystemConfiguration

// This struct will hold interface statistics
struct InterfaceStats {
	var inputBytes: UInt64 = 0
	var outputBytes: UInt64 = 0
	var interfaceName: String = ""
	var ipAddress: String = ""
}

// Class to get network interface statistics
class NetworkInterfaceStats {
	
	static func getAllInterfaces() -> [InterfaceStats] {
		var interfaces = [InterfaceStats]()
		
		// Get list of all network interfaces
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		guard getifaddrs(&ifaddr) == 0 else { return interfaces }
		defer { freeifaddrs(ifaddr) }
		
		// Loop through linked list of interfaces
		var ptr = ifaddr
		while ptr != nil {
			defer { ptr = ptr?.pointee.ifa_next }
			
			let interface = ptr?.pointee
			
			// Check if this is a valid interface
			let name = String(cString: (interface?.ifa_name)!)
			let family = interface?.ifa_addr.pointee.sa_family
			
			if family == UInt8(AF_LINK) {
				var stats = InterfaceStats()
				stats.interfaceName = name
				
				// Get traffic data
				if let data = interface?.ifa_data {
					// Different structs for different interfaces (e.g., en0 vs. lo0)
					// Cast to if_data to get traffic stats
					let networkData = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0 }
					
					stats.inputBytes = UInt64(networkData.pointee.ifi_ibytes)
					stats.outputBytes = UInt64(networkData.pointee.ifi_obytes)
					
					// Find IP address for this interface
					stats.ipAddress = getIPAddress(for: name)
					
					interfaces.append(stats)
				}
			}
		}
		
		return interfaces
	}
	
	static func getIPAddress(for interfaceName: String) -> String {
		var address = "Unknown"
		
		// Get list of all interfaces
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		guard getifaddrs(&ifaddr) == 0 else { return address }
		defer { freeifaddrs(ifaddr) }
		
		// Loop through linked list of interfaces
		var ptr = ifaddr
		while ptr != nil {
			defer { ptr = ptr?.pointee.ifa_next }
			
			let interface = ptr?.pointee
			let name = String(cString: (interface?.ifa_name)!)
			
			// Only process interfaces that match the requested name
			if name == interfaceName {
				// Only look for IPv4 interfaces
				let family = interface?.ifa_addr.pointee.sa_family
				if family == UInt8(AF_INET) {
					// Convert interface address to a human readable string
					var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
					getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
								&hostname, socklen_t(hostname.count),
								nil, socklen_t(0), NI_NUMERICHOST)
					address = String(cString: hostname)
				}
			}
		}
		
		return address
	}
	
	static func getPrimaryInterface() -> InterfaceStats? {
		// Get all interfaces
		let interfaces = getAllInterfaces()
		
		// Filter out loopback and non-physical interfaces
		let physicalInterfaces = interfaces.filter {
			!$0.interfaceName.hasPrefix("lo") &&
			!$0.interfaceName.hasPrefix("utun") &&
			!$0.interfaceName.hasPrefix("awdl")
		}
		
		// Try to find active interfaces with a valid IP
		let activeInterfaces = physicalInterfaces.filter { $0.ipAddress != "Unknown" }
		
		// Prioritize Wi-Fi and Ethernet interfaces
		let wifiInterface = activeInterfaces.first { $0.interfaceName.hasPrefix("en0") }
		let ethernetInterface = activeInterfaces.first { $0.interfaceName.hasPrefix("en1") }
		
		// Return the first available interface in order of priority
		return wifiInterface ?? ethernetInterface ?? activeInterfaces.first ?? physicalInterfaces.first
	}
	
	static func getInterfaceDescription(for name: String) -> String {
		// Common interface names and their descriptions
		switch name {
		case "en0":
			return "Wi-Fi"
		case "en1":
			return "Ethernet"
		case "en2":
			return "Ethernet 2"
		case "en3":
			return "Ethernet 3"
		case "en4":
			return "Thunderbolt Ethernet"
		case "en5":
			return "USB Ethernet"
		case "lo0":
			return "Loopback"
		default:
			if name.hasPrefix("en") {
				return "Network Interface"
			} else if name.hasPrefix("utun") {
				return "VPN Tunnel"
			} else if name.hasPrefix("awdl") {
				return "Apple Wireless Direct Link"
			} else {
				return name
			}
		}
	}
}
