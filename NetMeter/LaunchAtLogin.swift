//
//  LaunchAtLogin.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//


import Foundation
import ServiceManagement

class LaunchAtLogin {
    static func set(_ enable: Bool) {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        
        if #available(macOS 13.0, *) {
            // Use the new API on macOS 13 and later
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enable ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // Use the deprecated API for macOS 12 and earlier
            let success = SMLoginItemSetEnabled(bundleID as CFString, enable)
            if !success {
                print("Failed to \(enable ? "enable" : "disable") launch at login")
            }
        }
    }
}