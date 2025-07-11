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
		// This should be redundant with LSUIElement in Info.plist, but ensures it works
		NSApp.setActivationPolicy(.accessory)
		
		// Ensure we're not in the dock
		if NSApp.activationPolicy() != .accessory {
			NSApp.setActivationPolicy(.accessory)
		}
		
		// Hide the dock icon completely
		NSApp.dockTile.contentView = nil
		NSApp.dockTile.display()
	}
	
	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		// Always allow immediate termination
		return .terminateNow
	}
	
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		// Don't show any windows when the app is reopened
		return false
	}
}
