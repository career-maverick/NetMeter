//
//  SettingsView.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//


import SwiftUI

struct SettingsView: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @AppStorage("launchAtStartup") private var launchAtStartup = false
    @AppStorage("refreshInterval") private var refreshInterval = 1.0
    @AppStorage("showFullText") private var showFullText = true
    @AppStorage("theme") private var theme = "System Default"
    
    let refreshIntervalOptions = [0.5, 1.0, 2.0, 5.0]
    let themeOptions = ["Light", "Dark", "System Default"]
    
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
            
            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .padding(20)
        .frame(width: 450, height: 300)
    }
    
    private var generalSettingsView: some View {
        Form {
            Toggle("Launch at startup", isOn: $launchAtStartup)
                .onChange(of: launchAtStartup) { newValue in
					LaunchAtLogin.set(newValue)
                }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Refresh Interval")
                
                Picker("", selection: $refreshInterval) {
                    ForEach(refreshIntervalOptions, id: \.self) { interval in
                        Text("\(interval, specifier: "%.1f") seconds").tag(interval)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: refreshInterval) { newValue in
                    networkMonitor.setRefreshInterval(newValue)
                }
            }
            
            Divider()
            
            Button("Reset Statistics") {
                networkMonitor.resetStatistics()
            }
        }
        .padding()
    }
    
    private var displaySettingsView: some View {
        Form {
            Toggle("Show full text in menu bar", isOn: $showFullText)
                .onChange(of: showFullText) { newValue in
                    // We'll implement this functionality later when we connect
                    // this setting to the StatusBarManager
                }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Theme")
                
                Picker("", selection: $theme) {
                    ForEach(themeOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: theme) { newValue in
                    // We'll implement theme switching later
                }
            }
        }
        .padding()
    }
    
    private var aboutView: some View {
        VStack {
            Image(systemName: "speedometer")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .foregroundColor(.blue)
            
            Text("NetMeter")
                .font(.title)
                .padding(.top, 10)
            
            Text("Version 1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("A lightweight network monitoring app for macOS")
                .multilineTextAlignment(.center)
                .padding(.top, 5)
            
            Spacer()
            
            Text("© 2025 Your Name")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(networkMonitor: NetworkMonitor())
    }
}
