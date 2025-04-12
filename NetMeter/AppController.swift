//
//  AppController.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import SwiftUI
import Cocoa

class AppController: ObservableObject {
	// Use a simple property instead of a @Published property
	let networkMonitor = NetworkMonitor()
	var statusBarManager: StatusBarManager?
	var preferencesWindowController: NSWindowController?
	
	init() {
		// First create the status bar manager
		self.statusBarManager = StatusBarManager(networkMonitor: networkMonitor)
		
		// Register for notification without using self directly
		NotificationCenter.default.addObserver(
			forName: NSNotification.Name("showPreferencesWindow:"),
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.showPreferencesWindow()
		}
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	func showPreferencesWindow() {
		// Create window on-demand if it doesn't exist
		if preferencesWindowController == nil {
			createPreferencesWindow()
		}
		
		// Show window
		preferencesWindowController?.showWindow(nil)
		NSApp.activate(ignoringOtherApps: true)
	}
	
	private func createPreferencesWindow() {
		// Create a standard window
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		
		// Configure window
		window.title = "NetMeter Preferences"
		window.center()
		
		// Create static settings view
		let settingsView = SettingsView(networkMonitor: networkMonitor)
		let hostingController = NSHostingController(rootView: settingsView)
		
		// Set content
		window.contentViewController = hostingController
		
		// Create controller
		preferencesWindowController = NSWindowController(window: window)
	}
}
