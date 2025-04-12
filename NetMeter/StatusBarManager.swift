import SwiftUI
import AppKit

class StatusBarManager: NSObject {
	private var statusItem: NSStatusItem!
	private var popover: NSPopover!
	private var networkMonitor: NetworkMonitor
	private var timer: Timer?
	private var eventMonitor: Any?
	
	init(networkMonitor: NetworkMonitor) {
		self.networkMonitor = networkMonitor
		super.init()
		
		// Create status item with fixed width
		statusItem = NSStatusBar.system.statusItem(withLength: 180)
		
		// Setup popover
		setupPopover()
		
		// Configure button
		if let button = statusItem.button {
			button.target = self
			button.action = #selector(handleButtonClick)
			
			// Allow both left and right clicks
			button.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}
		
		// Start updating display
		startUpdatingDisplay()
		
		// Monitor clicks outside the popover
		setupEventMonitor()
	}
	
	deinit {
		timer?.invalidate()
		if let eventMonitor = eventMonitor {
			NSEvent.removeMonitor(eventMonitor)
		}
	}
	
	private func setupPopover() {
		popover = NSPopover()
		popover.contentSize = NSSize(width: 300, height: 350)
		popover.behavior = .transient
		popover.animates = true
		
		// Set content view
		let statsView = StatsView(networkMonitor: networkMonitor)
		popover.contentViewController = NSHostingController(rootView: statsView)
	}
	
	private func setupEventMonitor() {
		// Monitor clicks outside the popover to dismiss it
		eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
			guard let self = self, self.popover.isShown else { return }
			self.popover.close()
		}
	}
	
	private func startUpdatingDisplay() {
		// Update immediately
		updateDisplay()
		
		// Create timer
		timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
			self?.updateDisplay()
		}
	}
	
	private func updateDisplay() {
		guard let button = statusItem.button else { return }
			
		// Format speeds with shorter representations
		let upload = formatCompactSpeed(networkMonitor.uploadSpeed)
		let download = formatCompactSpeed(networkMonitor.downloadSpeed)
			
		// Use monospace font for consistent width
		let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
			
		// Create attributed string
		let attributedTitle = NSMutableAttributedString(string: "↑\(upload) ↓\(download)")
			
		// Apply font to the entire string
		attributedTitle.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedTitle.length))
			
		// Color the arrows for better visibility
		let upArrowRange = NSRange(location: 0, length: 1)
		let downArrowRange = NSRange(location: upload.count + 2, length: 1)
		attributedTitle.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: upArrowRange)
		attributedTitle.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: downArrowRange)
			
		button.attributedTitle = attributedTitle
	}
	
	// Helper function to format speeds in a more compact way
	private func formatCompactSpeed(_ bytesPerSecond: Double) -> String {
		let kb = bytesPerSecond / 1024
		let mb = kb / 1024
		let gb = mb / 1024
		
		if gb >= 1 {
			return String(format: "%.1fG", gb) // More compact format
		} else if mb >= 1 {
			return String(format: "%.1fM", mb) // More compact format
		} else if kb >= 1 {
			return String(format: "%.1fK", kb) // More compact format
		} else {
			return String(format: "%.0fB", bytesPerSecond) // More compact format
		}
	}
	
	@objc private func handleButtonClick() {
		if let event = NSApp.currentEvent {
			if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
				// Show the menu on right-click or ctrl+click
				showMenu()
			} else {
				// Show/hide popover on left-click
				togglePopover()
			}
		}
	}
	
	private func togglePopover() {
		if popover.isShown {
			popover.close()
		} else if let button = statusItem.button {
			popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
		}
	}
	
	private func showMenu() {
		// Create menu
		let menu = NSMenu()
		
		// Add menu items with targets
		let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
		prefsItem.target = self
		menu.addItem(prefsItem)
		
		menu.addItem(NSMenuItem.separator())
		
		let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)
		
		// Display the menu
		let location = NSEvent.mouseLocation
		menu.popUp(positioning: nil, at: location, in: nil)
	}
	
	@objc private func openPreferences() {
		NotificationCenter.default.post(name: NSNotification.Name("showPreferencesWindow:"), object: nil)
	}
	
	@objc private func quitApp() {
		NSApplication.shared.terminate(nil)
	}
}
