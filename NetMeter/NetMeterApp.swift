//
//  NetMeterApp.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/11/25.
//

import SwiftUI
import AppKit

@main
struct NetMeterApp: App {
	// Create the controller but don't observe it
	@StateObject private var appController = AppController()
	
	// Add app delegate
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	var body: some Scene {
		Settings {
			EmptyView()
		}
	}
}

class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		// Make the app a PURE background agent (no dock icon)
		NSApp.setActivationPolicy(.accessory)
		
		// Ensure we're not in the dock
		if NSApp.activationPolicy() != .accessory {
			NSApp.setActivationPolicy(.accessory)
		}
	}
	
	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		// Always allow immediate termination
		return .terminateNow
	}
}
