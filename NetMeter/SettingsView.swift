//
//  SettingsView.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var appController: AppController
    @AppStorage("launchAtStartup") private var launchAtStartup = false
    @AppStorage("refreshInterval") private var refreshInterval = 1.0
    @AppStorage("showFullText") private var showFullText = true
    @AppStorage("theme") private var theme = "System Default"
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoRetryOnError") private var autoRetryOnError = true
    
    let refreshIntervalOptions = [0.5, 1.0, 2.0, 5.0]
    let themeOptions = ["Light", "Dark", "System Default"]
    
    @State private var showResetAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        TabView {
            generalSettingsView
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            displaySettingsView
                .tabItem {
                    Label("Display", systemImage: "display")
                }
            
            networkSettingsView
                .tabItem {
                    Label("Network", systemImage: "network")
                }
            
            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .padding(20)
        .frame(width: 500, height: 400)
        .alert("Reset Statistics", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetStatistics()
            }
        } message: {
            Text("This will permanently delete all network usage statistics. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
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
    
    private var generalSettingsView: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at startup", isOn: $launchAtStartup)
                    .onChange(of: launchAtStartup) { _, newValue in
                        LaunchAtLogin.set(newValue)
                    }
            }
            
            Section("Monitoring") {
                VStack(alignment: .leading) {
                    Text("Refresh Interval")
                        .font(.headline)
                    
                    Picker("", selection: $refreshInterval) {
                        ForEach(refreshIntervalOptions, id: \.self) { interval in
                            Text("\(interval, specifier: "%.1f") seconds").tag(interval)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: refreshInterval) { _, newValue in
                        networkMonitor.setRefreshInterval(newValue)
                    }
                    
                    Text("Lower values provide more frequent updates but use more CPU")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Show notifications", isOn: $showNotifications)
                Toggle("Auto-retry on error", isOn: $autoRetryOnError)
            }
            
            Section("Data Management") {
                Button("Reset Statistics") {
                    showResetAlert = true
                }
                .foregroundColor(.red)
                
                Text("This will clear all network usage history")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var displaySettingsView: some View {
        Form {
            Section("Menu Bar Display") {
                Toggle("Show full text in menu bar", isOn: $showFullText)
                    .onChange(of: showFullText) { _, newValue in
                        // This will be handled by StatusBarManager
                        NotificationCenter.default.post(
                            name: NSNotification.Name("updateMenuBarDisplay"),
                            object: nil
                        )
                    }
                
                VStack(alignment: .leading) {
                    Text("Theme")
                        .font(.headline)
                    
                    Picker("", selection: $theme) {
                        ForEach(themeOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: theme) { _, newValue in
                        // This will be handled by the app's theme manager
                        NotificationCenter.default.post(
                            name: NSNotification.Name("updateTheme"),
                            object: newValue
                        )
                    }
                }
            }
            
            Section("Statistics Display") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Network Status")
                        .font(.headline)
                    
                    HStack {
                        Text("Interface:")
                        Text(networkMonitor.interfaceDescription)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status:")
                        Text(networkStatusText)
                            .foregroundColor(networkStatusColor)
                    }
                    
                    HStack {
                        Text("Local IP:")
                        Text(networkMonitor.ipAddress)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
    
    private var networkSettingsView: some View {
        Form {
            Section("Network Information") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Interface:")
                        Text("\(networkMonitor.interfaceDescription) (\(networkMonitor.interfaceName))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Local IP:")
                        Text(networkMonitor.ipAddress)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("External IP:")
                        Text(networkMonitor.externalIPAddress)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Uptime:")
                        Text(formatUptime(networkMonitor.networkUptime))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Network Actions") {
                Button("Refresh External IP") {
                    // This would trigger a refresh of the external IP
                    NotificationCenter.default.post(
                        name: NSNotification.Name("refreshExternalIP"),
                        object: nil
                    )
                }
                
                Button("Restart Monitoring") {
                    networkMonitor.restartMonitoring()
                }
                
                Button("Test Network Connection") {
                    testNetworkConnection()
                }
            }
            
            Section("Performance") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Upload:")
                        Text(networkMonitor.formatSpeed(networkMonitor.uploadSpeed))
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Current Download:")
                        Text(networkMonitor.formatSpeed(networkMonitor.downloadSpeed))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Peak Upload:")
                        Text(networkMonitor.formatSpeed(networkMonitor.peakUploadSpeed))
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Peak Download:")
                        Text(networkMonitor.formatSpeed(networkMonitor.peakDownloadSpeed))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
    }
    
    private var aboutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "speedometer")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("NetMeter")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("A lightweight network monitoring app for macOS")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("Features:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("• Real-time network speed monitoring")
                    Text("• Daily and weekly usage statistics")
                    Text("• Multiple network interface support")
                    Text("• Low resource usage")
                    Text("• Native macOS integration")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("© 2025 NetMeter")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Built with SwiftUI for macOS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
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
    
    private func formatUptime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func resetStatistics() {
        networkMonitor.resetStatistics()
        
        // Show success feedback using modern UserNotifications
        let content = UNMutableNotificationContent()
        content.title = "NetMeter"
        content.body = "Statistics have been reset"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func testNetworkConnection() {
        // Simple network connectivity test
        let url = URL(string: "https://www.apple.com")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Network test failed: \(error.localizedDescription)"
                    self.showErrorAlert = true
                } else {
                    // Show success notification using modern UserNotifications
                    let content = UNMutableNotificationContent()
                    content.title = "NetMeter"
                    content.body = "Network connection test successful"
                    content.sound = .default
                    
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: nil
                    )
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Failed to show notification: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        task.resume()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            networkMonitor: NetworkMonitor(),
            appController: AppController()
        )
    }
}
