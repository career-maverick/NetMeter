//
//  StatsView.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var appController: AppController
    @ObservedObject var appState: AppState
    @State private var showWeeklyStats = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            if case .error(let error) = networkMonitor.networkStatus {
                errorSection(error: error)
            } else {
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
        }
        .padding()
        .frame(width: 320)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
        .alert("Network Error", isPresented: $showErrorAlert) {
            Button("OK") { }
            Button("Retry") {
                networkMonitor.restartMonitoring()
            }
        } message: {
            Text(errorMessage)
        }
        .onReceive(networkMonitor.$lastError) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("NetMeter")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(networkStatusText)
                    .font(.caption)
                    .foregroundColor(networkStatusColor)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    showWeeklyStats.toggle()
                }) {
                    Image(systemName: showWeeklyStats ? "chart.bar.fill" : "chart.bar")
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Weekly Statistics")
                
                Button(action: {
                    appController.showPreferencesWindow()
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open Settings")
                
                Button(action: {
                    appController.quitApplication()
                }) {
                    Image(systemName: "power")
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Quit NetMeter")
            }
        }
    }
    
    private var networkStatusText: String {
        switch networkMonitor.networkStatus {
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private var networkStatusColor: Color {
        switch networkMonitor.networkStatus {
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .connecting:
            return .orange
        case .error:
            return .red
        }
    }
    
    private func errorSection(error: NetworkMonitorError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Network Error")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Retry Connection") {
                networkMonitor.restartMonitoring()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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
                            .font(.system(.body, design: .monospaced))
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
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }
    
    private var dataUsageSection: some View {
        let todayStats = appState.getStatsForToday()
        return VStack(alignment: .leading, spacing: 8) {
            Text("Data Usage Today")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Uploaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.formatBytes(Double(todayStats.totalUploaded)))
                        .foregroundColor(.primary)
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.formatBytes(Double(todayStats.totalDownloaded)))
                        .foregroundColor(.primary)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Peak Upload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.formatSpeed(networkMonitor.peakUploadSpeed))
                        .foregroundColor(.primary)
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Peak Download")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.formatSpeed(networkMonitor.peakDownloadSpeed))
                        .foregroundColor(.primary)
                        .font(.system(.body, design: .monospaced))
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
                        .font(.system(.caption, design: .monospaced))
                }
                
                HStack {
                    Text("Local IP:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.ipAddress)
                        .foregroundColor(.primary)
                        .font(.system(.caption, design: .monospaced))
                }
                
                HStack {
                    Text("External IP:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.externalIPAddress)
                        .foregroundColor(.primary)
                        .font(.system(.caption, design: .monospaced))
                }
                
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if case .connected = networkMonitor.networkStatus {
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
                        .font(.system(.caption, design: .monospaced))
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

// MARK: - Preview
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        let monitor = NetworkMonitor()
        StatsView(
            networkMonitor: monitor,
            appController: AppController(),
            appState: monitor.appState
        )
    }
}
