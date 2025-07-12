//
//  NetworkMonitor.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//
import Foundation
import Network
import os.log

// MARK: - Network Monitoring Errors
enum NetworkMonitorError: Error, LocalizedError {
    case interfaceNotFound
    case invalidInterfaceData
    case externalIPFetchFailed
    case networkPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .interfaceNotFound:
            return "No active network interface found"
        case .invalidInterfaceData:
            return "Invalid network interface data"
        case .externalIPFetchFailed:
            return "Failed to fetch external IP address"
        case .networkPermissionDenied:
            return "Network access permission denied"
        }
    }
}

// MARK: - Network Status
enum NetworkStatus {
    case connected
    case disconnected
    case connecting
    case error(NetworkMonitorError)
}

class NetworkMonitor: ObservableObject {
    // MARK: - Published Properties
    @Published var uploadSpeed: Double = 0
    @Published var downloadSpeed: Double = 0
    @Published var totalUploadedToday: UInt64 = 0
    @Published var totalDownloadedToday: UInt64 = 0
    @Published var peakUploadSpeed: Double = 0
    @Published var peakDownloadSpeed: Double = 0
    @Published var interfaceName: String = "Unknown"
    @Published var interfaceDescription: String = "Unknown"
    @Published var ipAddress: String = "Unknown"
    @Published var externalIPAddress: String = "Unknown"
    @Published var networkUptime: TimeInterval = 0
    @Published var networkStatus: NetworkStatus = .disconnected
    @Published var lastError: NetworkMonitorError?
    @Published var appState = AppState()
    
    // MARK: - Private Properties
    private var previousUploadBytes: UInt64 = 0
    private var previousDownloadBytes: UInt64 = 0
    private var lastUpdateTime: Date = Date()
    private var startTime: Date = Date()
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 1.0
    private var skipNextDelta: Bool = false
    private var sampleTimer: Timer?
    private var uiUpdateTimer: Timer?
    private let sampleInterval: TimeInterval = 0.1 // 100ms
    private let uiUpdateInterval: TimeInterval = 0.5 // 500ms
    private var accumulatedUpload: UInt64 = 0
    private var accumulatedDownload: UInt64 = 0
    
    // Network monitoring
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue", qos: .utility)
    
    // Performance tracking
    private var updateCount: Int = 0
    private var lastPerformanceCheck: Date = Date()
    
    // External IP fetching
    private var externalIPTask: URLSessionDataTask?
    private let externalIPQueue = DispatchQueue(label: "ExternalIPQueue", qos: .utility)
    
    // Logging
    private let logger = Logger(subsystem: "com.netmeter.app", category: "NetworkMonitor")
    
    // MARK: - Initialization
    init() {
        logger.info("Initializing NetworkMonitor")
        startConnectionMonitoring()
        startMonitoring()
        fetchExternalIPAddress()
    }
    
    deinit {
        logger.info("Deinitializing NetworkMonitor")
        stopMonitoring()
        monitor.cancel()
        externalIPTask?.cancel()
    }
    
    // MARK: - Public Methods
    func restartMonitoring() {
        logger.info("Restarting network monitoring")
        stopMonitoring()
        startMonitoring()
    }
    
    func startMonitoring() {
        // Reset counters and state
        startTime = Date()
        lastUpdateTime = Date()
        previousUploadBytes = 0
        previousDownloadBytes = 0
        updateCount = 0
        lastPerformanceCheck = Date()
        accumulatedUpload = 0
        accumulatedDownload = 0
        // Clear any previous errors
        DispatchQueue.main.async {
            self.lastError = nil
        }
        // Start high-frequency sampling timer
        sampleTimer?.invalidate()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.sampleNetworkStats()
        }
        // Start UI update timer
        uiUpdateTimer?.invalidate()
        uiUpdateTimer = Timer.scheduledTimer(withTimeInterval: uiUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePublishedStats()
        }
        logger.info("Network monitoring started with sample interval: \(self.sampleInterval)s, UI update interval: \(self.uiUpdateInterval)s")
    }
    
    func stopMonitoring() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        uiUpdateTimer?.invalidate()
        uiUpdateTimer = nil
        logger.info("Network monitoring stopped")
    }
    
    func setRefreshInterval(_ interval: TimeInterval) {
        guard interval > 0 else {
            logger.error("Invalid refresh interval: \(interval)")
            return
        }
        
        refreshInterval = interval
        stopMonitoring()
        startMonitoring()
        logger.info("Refresh interval updated to: \(interval)s")
    }
    
    func resetStatistics() {
        logger.info("Resetting all statistics")
        
        DispatchQueue.main.async {
            self.totalUploadedToday = 0
            self.totalDownloadedToday = 0
            self.peakUploadSpeed = 0
            self.peakDownloadSpeed = 0
            // Set previous byte counters to current interface values
            if let iface = try? NetworkInterfaceStats.getPrimaryInterface() {
                self.previousUploadBytes = iface.outputBytes
                self.previousDownloadBytes = iface.inputBytes
            } else {
                self.previousUploadBytes = 0
                self.previousDownloadBytes = 0
            }
            self.skipNextDelta = true
        }
        
        startTime = Date()
    }
    
    // MARK: - Private Methods
    private func startConnectionMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        switch path.status {
        case .satisfied:
            self.networkStatus = .connected
            if let interfaceName = path.availableInterfaces.first?.name {
                self.interfaceName = interfaceName
                self.interfaceDescription = self.getInterfaceDescription(for: interfaceName)
            }
            self.logger.info("Network connected via: \(self.interfaceName)")
            
        case .unsatisfied:
            self.networkStatus = .disconnected
            self.logger.warning("Network disconnected")
            
        case .requiresConnection:
            self.networkStatus = .connecting
            self.logger.info("Network connecting...")
            
        @unknown default:
            self.networkStatus = .error(.interfaceNotFound)
            self.logger.error("Unknown network status")
        }
    }
    
    private func sampleNetworkStats() {
        guard case .connected = networkStatus else { return }
        do {
            let interface = try NetworkInterfaceStats.getPrimaryInterface()
            guard let interface = interface else { return }
            DispatchQueue.main.async {
                self.ipAddress = interface.ipAddress
                if self.skipNextDelta {
                    self.skipNextDelta = false
                    self.previousUploadBytes = interface.outputBytes
                    self.previousDownloadBytes = interface.inputBytes
                    return
                }
                let uploadDelta = self.calculateSafeDelta(current: interface.outputBytes, previous: self.previousUploadBytes)
                let downloadDelta = self.calculateSafeDelta(current: interface.inputBytes, previous: self.previousDownloadBytes)
                self.accumulatedUpload += uploadDelta
                self.accumulatedDownload += downloadDelta
                self.previousUploadBytes = interface.outputBytes
                self.previousDownloadBytes = interface.inputBytes
                // Persist to AppState for daily stats
                self.appState.addDailyStatistics(for: Date(), uploaded: uploadDelta, downloaded: downloadDelta)
            }
        } catch {
            logger.error("Error sampling network stats: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = error as? NetworkMonitorError
                self.networkStatus = .error(error as? NetworkMonitorError ?? .invalidInterfaceData)
            }
        }
    }
    
    private func updatePublishedStats() {
        DispatchQueue.main.async {
            self.totalUploadedToday += self.accumulatedUpload
            self.totalDownloadedToday += self.accumulatedDownload
            // Calculate speeds for display (over the UI update interval)
            self.uploadSpeed = Double(self.accumulatedUpload) / self.uiUpdateInterval
            self.downloadSpeed = Double(self.accumulatedDownload) / self.uiUpdateInterval
            if self.uploadSpeed > self.peakUploadSpeed {
                self.peakUploadSpeed = self.uploadSpeed
            }
            if self.downloadSpeed > self.peakDownloadSpeed {
                self.peakDownloadSpeed = self.downloadSpeed
            }
            self.accumulatedUpload = 0
            self.accumulatedDownload = 0
            self.networkUptime = Date().timeIntervalSince(self.startTime)
        }
    }
    
    private func calculateSpeeds(currentUpload: UInt64, currentDownload: UInt64, timeInterval: TimeInterval) -> (upload: Double, download: Double) {
        let uploadDelta = calculateSafeDelta(current: currentUpload, previous: previousUploadBytes)
        let downloadDelta = calculateSafeDelta(current: currentDownload, previous: previousDownloadBytes)
        
        let uploadSpeed = Double(uploadDelta) / timeInterval
        let downloadSpeed = Double(downloadDelta) / timeInterval
        
        return (uploadSpeed, downloadSpeed)
    }
    
    private func calculateSafeDelta(current: UInt64, previous: UInt64) -> UInt64 {
        // Handle counter reset or overflow
        if current >= previous {
            return current - previous
        } else {
            // Counter reset or overflow occurred
            logger.debug("Counter reset detected: current=\(current), previous=\(previous)")
            return current
        }
    }
    
    private func checkPerformance() {
        let now = Date()
        let timeSinceLastCheck = now.timeIntervalSince(lastPerformanceCheck)
        
        if timeSinceLastCheck > 0 {
            let updatesPerSecond = Double(updateCount) / timeSinceLastCheck
            logger.debug("Performance: \(updatesPerSecond) updates/second")
        }
        
        // Reset counters
        updateCount = 0
        lastPerformanceCheck = now
    }
    
    private func fetchExternalIPAddress() {
        // Cancel any existing task
        externalIPTask?.cancel()
        
        // Use multiple fallback services for reliability
        let services = [
            "https://api.ipify.org?format=json",
            "https://httpbin.org/ip",
            "https://icanhazip.com"
        ]
        
        fetchExternalIPFromServices(services, currentIndex: 0)
    }
    
    private func fetchExternalIPFromServices(_ services: [String], currentIndex: Int) {
        guard currentIndex < services.count else {
            logger.error("All external IP services failed")
            DispatchQueue.main.async {
                self.externalIPAddress = "Unavailable"
                self.lastError = .externalIPFetchFailed
            }
            return
        }
        
        guard let url = URL(string: services[currentIndex]) else {
            fetchExternalIPFromServices(services, currentIndex: currentIndex + 1)
            return
        }
        
        externalIPTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("External IP fetch failed for \(services[currentIndex]): \(error.localizedDescription)")
                self.fetchExternalIPFromServices(services, currentIndex: currentIndex + 1)
                return
            }
            
            guard let data = data else {
                self.fetchExternalIPFromServices(services, currentIndex: currentIndex + 1)
                return
            }
            
            // Try to parse the response
            if let ip = self.parseExternalIPResponse(data: data, service: services[currentIndex]) {
                DispatchQueue.main.async {
                    self.externalIPAddress = ip
                    self.lastError = nil
                }
                self.logger.info("External IP fetched successfully: \(ip)")
            } else {
                self.fetchExternalIPFromServices(services, currentIndex: currentIndex + 1)
            }
        }
        
        externalIPTask?.resume()
    }
    
    private func parseExternalIPResponse(data: Data, service: String) -> String? {
        do {
            if service.contains("ipify") {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                   let ip = json["ip"] {
                    return ip
                }
            } else if service.contains("httpbin") {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                   let ip = json["origin"] {
                    return ip
                }
            } else if service.contains("icanhazip") {
                if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return ip
                }
            }
        } catch {
            logger.error("Failed to parse external IP response: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func getInterfaceDescription(for name: String) -> String {
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
    
    // MARK: - Helper Methods
    func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }
    
    func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB/s", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB/s", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB/s", kb)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
