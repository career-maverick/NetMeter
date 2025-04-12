//
//  StatsView.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import SwiftUI

struct StatsView: View {
	@ObservedObject var networkMonitor: NetworkMonitor
	@State private var appState = AppState()
	@State private var showWeeklyStats = false
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			headerSection
			
			Divider()
			
			currentSpeedsSection
			
			Divider()
			
			dataUsageSection
			
			if showWeeklyStats {
				Divider()
				
				weeklyStatsSection
			}
			
			Divider()
			
			networkInfoSection
		}
		.padding()
		.frame(width: 300)
		.background(VisualEffectView().edgesIgnoringSafeArea(.all))
	}
	
	private var headerSection: some View {
		HStack {
			Text("NetMeter")
				.font(.headline)
				.foregroundColor(.primary)
			
			Spacer()
			
			Button(action: {
				showWeeklyStats.toggle()
			}) {
				Image(systemName: showWeeklyStats ? "chart.bar.fill" : "chart.bar")
					.foregroundColor(.primary)
			}
			.buttonStyle(PlainButtonStyle())
			.help("Toggle Weekly Statistics")
			
			Button(action: {
				NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
			}) {
				Image(systemName: "gear")
					.foregroundColor(.primary)
			}
			.buttonStyle(PlainButtonStyle())
			.help("Open Settings")
		}
	}
	
	private var currentSpeedsSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Current Activity")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			HStack(spacing: 20) {
				VStack(alignment: .leading) {
					Text("Upload")
						.font(.caption)
						.foregroundColor(.secondary)
					
					HStack(spacing: 4) {
						Image(systemName: "arrow.up")
							.foregroundColor(.green)
						Text(networkMonitor.formatSpeed(networkMonitor.uploadSpeed))
							.foregroundColor(.primary)
					}
				}
				
				VStack(alignment: .leading) {
					Text("Download")
						.font(.caption)
						.foregroundColor(.secondary)
					
					HStack(spacing: 4) {
						Image(systemName: "arrow.down")
							.foregroundColor(.blue)
						Text(networkMonitor.formatSpeed(networkMonitor.downloadSpeed))
							.foregroundColor(.primary)
					}
				}
			}
		}
	}
	
	private var dataUsageSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Data Usage Today")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			HStack(spacing: 20) {
				VStack(alignment: .leading) {
					Text("Uploaded")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(networkMonitor.formatBytes(Double(networkMonitor.totalUploadedToday)))
						.foregroundColor(.primary)
				}
				
				VStack(alignment: .leading) {
					Text("Downloaded")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(networkMonitor.formatBytes(Double(networkMonitor.totalDownloadedToday)))
						.foregroundColor(.primary)
				}
			}
			
			HStack(spacing: 20) {
				VStack(alignment: .leading) {
					Text("Peak Upload")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(networkMonitor.formatSpeed(networkMonitor.peakUploadSpeed))
						.foregroundColor(.primary)
				}
				
				VStack(alignment: .leading) {
					Text("Peak Download")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(networkMonitor.formatSpeed(networkMonitor.peakDownloadSpeed))
						.foregroundColor(.primary)
				}
			}
		}
	}
	
	private var weeklyStatsSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Weekly Overview")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			VStack(alignment: .leading, spacing: 4) {
				ForEach(appState.getStatsForLast7Days()) { stat in
					HStack {
						Text(formatDate(stat.date))
							.font(.caption)
							.foregroundColor(.secondary)
							.frame(width: 80, alignment: .leading)
						
						VStack(alignment: .leading) {
							Text("↑ \(networkMonitor.formatBytes(Double(stat.totalUploaded)))")
								.font(.caption)
								.foregroundColor(.green)
						}
						
						VStack(alignment: .leading) {
							Text("↓ \(networkMonitor.formatBytes(Double(stat.totalDownloaded)))")
								.font(.caption)
								.foregroundColor(.blue)
						}
						
						Spacer()
					}
				}
			}
		}
	}
	
	private var networkInfoSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Network Information")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text("Interface:")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text("\(networkMonitor.interfaceDescription) (\(networkMonitor.interfaceName))")
						.foregroundColor(.primary)
				}
				
				HStack {
					Text("Local IP:")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(networkMonitor.ipAddress)
						.foregroundColor(.primary)
				}
				
				HStack {
					Text("External IP:")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(networkMonitor.externalIPAddress)
						.foregroundColor(.primary)
				}
				
				HStack {
					Text("Status:")
						.font(.caption)
						.foregroundColor(.secondary)
					
					if networkMonitor.isConnected {
						Text("Connected")
							.foregroundColor(.green)
					} else {
						Text("Disconnected")
							.foregroundColor(.red)
					}
				}
				
				HStack {
					Text("Uptime:")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Text(formatUptime(networkMonitor.networkUptime))
						.foregroundColor(.primary)
				}
			}
		}
	}
	
	// Helper function to format uptime
	private func formatUptime(_ timeInterval: TimeInterval) -> String {
		let hours = Int(timeInterval) / 3600
		let minutes = (Int(timeInterval) % 3600) / 60
		let seconds = Int(timeInterval) % 60
		
		return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
	}
	
	// Helper function to format dates
	private func formatDate(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "E, MMM d"
		return formatter.string(from: date)
	}
}

// This creates the blur effect background for our popover
struct VisualEffectView: NSViewRepresentable {
	func makeNSView(context: Context) -> NSVisualEffectView {
		let view = NSVisualEffectView()
		view.blendingMode = .behindWindow
		view.state = .active
		view.material = .hudWindow
		return view
	}
	
	func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
		// No update needed
	}
}
