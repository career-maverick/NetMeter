//
//  NetworkMonitor.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//
import Foundation
import Network

class NetworkMonitor: ObservableObject {
	// Published properties that will update the UI when they change
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
	@Published var isConnected: Bool = true
	
	// Private properties to track network usage
	private var previousUploadBytes: UInt64 = 0
	private var previousDownloadBytes: UInt64 = 0
	private var lastUpdateTime: Date = Date()
	private var startTime: Date = Date()
	private var refreshTimer: Timer?
	private var refreshInterval: TimeInterval = 1.0
	
	// For tracking connection status
	private let monitor = NWPathMonitor()
	private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
	
	init() {
		startConnectionMonitoring()
		startMonitoring()
		fetchExternalIPAddress()
	}
	
	deinit {
		stopMonitoring()
		monitor.cancel()
	}
	
	private func startConnectionMonitoring() {
		monitor.pathUpdateHandler = { [weak self] path in
			DispatchQueue.main.async {
				self?.isConnected = path.status == .satisfied
				
				// Get interface name if possible
				if let interfaceName = path.availableInterfaces.first?.name {
					self?.interfaceName = interfaceName
					self?.interfaceDescription = self?.getInterfaceDescription(for: interfaceName) ?? "Network Interface"
				}
			}
		}
		monitor.start(queue: monitorQueue)
	}
	
	func restartMonitoring() {
		stopMonitoring()
		startMonitoring()
	}
	
	func startMonitoring() {
		// Reset counters
		startTime = Date()
		lastUpdateTime = Date()
		
		// Initialize bytes to zero for fresh counting
		previousUploadBytes = 0
		previousDownloadBytes = 0
		
		// Start refresh timer
		refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
			self?.updateNetworkStats()
		}
	}
	
	func stopMonitoring() {
		refreshTimer?.invalidate()
		refreshTimer = nil
	}
	
	func updateNetworkStats() {
		// Skip update if not connected
		guard isConnected else { return }
		
		// Get current timestamp
		let currentTime = Date()
		let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
		
		// Get current interface stats
		if let interface = NetworkInterfaceStats.getPrimaryInterface() {
			// Update interface info
			interfaceName = interface.interfaceName
			interfaceDescription = NetworkInterfaceStats.getInterfaceDescription(for: interface.interfaceName)
			ipAddress = interface.ipAddress
			
			// Calculate speeds (bytes per second) with safety checks
			let currentUploadBytes = interface.outputBytes
			let currentDownloadBytes = interface.inputBytes
			
			// Safe calculation of deltas with overflow prevention
			var uploadDelta: UInt64 = 0
			var downloadDelta: UInt64 = 0
			
			// Check if the current value is greater than previous
			if currentUploadBytes >= previousUploadBytes {
				uploadDelta = currentUploadBytes - previousUploadBytes
			} else {
				// Handle counter reset or overflow
				uploadDelta = currentUploadBytes
			}
			
			if currentDownloadBytes >= previousDownloadBytes {
				downloadDelta = currentDownloadBytes - previousDownloadBytes
			} else {
				// Handle counter reset or overflow
				downloadDelta = currentDownloadBytes
			}
			
			// Guard against division by zero
			if timeInterval > 0 {
				uploadSpeed = Double(uploadDelta) / timeInterval
				downloadSpeed = Double(downloadDelta) / timeInterval
			} else {
				uploadSpeed = 0
				downloadSpeed = 0
			}
			
			// Update peak speeds if necessary
			if uploadSpeed > peakUploadSpeed {
				peakUploadSpeed = uploadSpeed
			}
			
			if downloadSpeed > peakDownloadSpeed {
				peakDownloadSpeed = downloadSpeed
			}
			
			// Update totals for today
			totalUploadedToday = totalUploadedToday.addingReportingOverflow(uploadDelta).partialValue
			totalDownloadedToday = totalDownloadedToday.addingReportingOverflow(downloadDelta).partialValue
			
			// Update previous values for next calculation
			previousUploadBytes = currentUploadBytes
			previousDownloadBytes = currentDownloadBytes
		}
		
		// Update network uptime
		networkUptime = Date().timeIntervalSince(startTime)
		
		// Update time for next interval
		lastUpdateTime = currentTime
	}
	
	func setRefreshInterval(_ interval: TimeInterval) {
		refreshInterval = interval
		stopMonitoring()
		startMonitoring()
	}
	
	func resetStatistics() {
		// Reset all counters
		totalUploadedToday = 0
		totalDownloadedToday = 0
		peakUploadSpeed = 0
		peakDownloadSpeed = 0
		previousUploadBytes = 0
		previousDownloadBytes = 0
		startTime = Date()
	}
	
	private func fetchExternalIPAddress() {
		guard let url = URL(string: "https://api.ipify.org?format=json") else { return }
		
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let data = data, error == nil else {
				DispatchQueue.main.async {
					self?.externalIPAddress = "Unavailable"
				}
				return
			}
			
			do {
				if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
				   let ip = json["ip"] {
					DispatchQueue.main.async {
						self?.externalIPAddress = ip
					}
				}
			} catch {
				DispatchQueue.main.async {
					self?.externalIPAddress = "Unavailable"
				}
			}
		}
		
		task.resume()
	}
	
	private func getLocalIPAddress() -> String {
		var address = "Unknown"
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		
		guard getifaddrs(&ifaddr) == 0 else { return address }
		defer { freeifaddrs(ifaddr) }
		
		var ptr = ifaddr
		while ptr != nil {
			defer { ptr = ptr?.pointee.ifa_next }
			
			let interface = ptr?.pointee
			let addrFamily = interface?.ifa_addr.pointee.sa_family
			
			if addrFamily == UInt8(AF_INET) {
				// Get interface name
				let name = String(cString: (interface?.ifa_name)!)
				
				// Skip loopback interfaces
				if name == "lo0" { continue }
				
				// Convert interface address to a human readable string
				var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
				getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
							&hostname, socklen_t(hostname.count),
							nil, socklen_t(0), NI_NUMERICHOST)
				address = String(cString: hostname)
			}
		}
		
		return address
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
	
	// Helper to format byte values with appropriate units
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
	
	// Helper to format speed values with appropriate units
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
