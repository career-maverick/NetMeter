import SwiftUI
import AppKit
import os.log

// MARK: - Status Bar Manager Errors
enum StatusBarManagerError: Error, LocalizedError {
    case failedToCreateStatusItem
    case failedToCreatePopover
    case failedToUpdateDisplay
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateStatusItem:
            return "Failed to create status bar item"
        case .failedToCreatePopover:
            return "Failed to create popover"
        case .failedToUpdateDisplay:
            return "Failed to update status bar display"
        }
    }
}

class StatusBarManager: NSObject {
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var networkMonitor: NetworkMonitor
    private var appController: AppController
    private var timer: Timer?
    private var eventMonitor: Any?
    
    // User preferences
    @AppStorage("showCompactDisplay") private var showCompactDisplay = false
    @AppStorage("showSpeedUnits") private var showSpeedUnits = true
    @AppStorage("displayFormat") private var displayFormat = "both" // "both", "upload", "download"
    
    // Performance tracking
    private var updateCount = 0
    private var lastPerformanceCheck = Date()
    
    // Logging
    private let logger = Logger(subsystem: "com.netmeter.app", category: "StatusBarManager")
    
    // MARK: - Initialization
    init(networkMonitor: NetworkMonitor, appController: AppController) {
        self.networkMonitor = networkMonitor
        self.appController = appController
        super.init()
        
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        startUpdatingDisplay()
        
        logger.info("StatusBarManager initialized successfully")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup Methods
    private func setupStatusItem() {
        // Create status item with appropriate length
        let length: CGFloat = showCompactDisplay ? 140 : 180
        statusItem = NSStatusBar.system.statusItem(withLength: length)
        
        guard let button = statusItem?.button else {
            logger.error("Failed to get status item button")
            return
        }
        
        // Configure button
        button.target = self
        button.action = #selector(handleButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Set accessibility properties
        button.setAccessibilityLabel("NetMeter Network Monitor")
        
        logger.info("Status item created with length: \(length)")
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        
        // Set content view
        let statsView = StatsView(networkMonitor: networkMonitor, appController: appController)
        popover?.contentViewController = NSHostingController(rootView: statsView)
        logger.info("Popover setup completed")
    }
    
    private func setupEventMonitor() {
        // Monitor clicks outside the popover to dismiss it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let popover = self.popover, popover.isShown else { return }
            
            // Don't close if clicking on the status item
            if let button = self.statusItem?.button, button.frame.contains(event.locationInWindow) {
                return
            }
            
            popover.close()
        }
    }
    
    // MARK: - Display Methods
    private func startUpdatingDisplay() {
        // Update immediately
        updateDisplay()
        
        // Create timer with appropriate interval
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        
        logger.info("Display update timer started")
    }
    
    private func updateDisplay() {
        updateCount += 1
        
        // Performance monitoring
        if updateCount % 100 == 0 {
            checkPerformance()
        }
        
        guard let button = statusItem?.button else {
            logger.error("Status item button not available")
            return
        }
        
        do {
            let attributedTitle = try createAttributedTitle()
            button.attributedTitle = attributedTitle
            
            // Update accessibility value
            button.setAccessibilityValue(createAccessibilityValue())
            
        } catch {
            logger.error("Failed to update display: \(error.localizedDescription)")
            // Fallback to simple text
            button.title = "NetMeter"
        }
    }
    
    private func createAttributedTitle() throws -> NSAttributedString {
        // Format speeds based on user preferences
        let upload = formatSpeedForDisplay(networkMonitor.uploadSpeed)
        let download = formatSpeedForDisplay(networkMonitor.downloadSpeed)
        
        // Create base string based on display format
        let baseString: String
        switch displayFormat {
        case "upload":
            baseString = "↑\(upload)"
        case "download":
            baseString = "↓\(download)"
        default:
            baseString = "↓\(download) ↑\(upload)"
        }
        
        // Use monospace font for consistent width
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        
        // Create attributed string
        let attributedTitle = NSMutableAttributedString(string: baseString)
        attributedTitle.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedTitle.length))
        
        // Color the arrows and values based on network status
        let colors = getColorsForNetworkStatus()
        
        // Apply colors to different parts
        if displayFormat != "upload" {
            let downArrowStart = displayFormat == "download" ? 0 : 0
            let downArrowRange = NSRange(location: downArrowStart, length: 1)
            let downloadRange = NSRange(location: downArrowStart + 1, length: download.count)
            attributedTitle.addAttribute(.foregroundColor, value: colors.download, range: downArrowRange)
            attributedTitle.addAttribute(.foregroundColor, value: colors.download, range: downloadRange)
        }
        
        if displayFormat != "download" {
            let upArrowStart = displayFormat == "upload" ? 0 : download.count + 2
            let upArrowRange = NSRange(location: upArrowStart, length: 1)
            let uploadRange = NSRange(location: upArrowStart + 1, length: upload.count)
            attributedTitle.addAttribute(.foregroundColor, value: colors.upload, range: upArrowRange)
            attributedTitle.addAttribute(.foregroundColor, value: colors.upload, range: uploadRange)
        }
        
        return attributedTitle
    }
    
    private func formatSpeedForDisplay(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        let value: Double
        let unit: String
        
        if gb >= 1 {
            value = gb
            unit = showSpeedUnits ? "G" : ""
        } else if mb >= 1 {
            value = mb
            unit = showSpeedUnits ? "M" : ""
        } else if kb >= 1 {
            value = kb
            unit = showSpeedUnits ? "K" : ""
        } else {
            value = bytesPerSecond
            unit = showSpeedUnits ? "B" : ""
        }
        
        let format = showCompactDisplay ? "%.1f" : "%.2f"
        return String(format: format + unit, value)
    }
    
    private func getColorsForNetworkStatus() -> (upload: NSColor, download: NSColor) {
        switch networkMonitor.networkStatus {
        case .connected:
            return (NSColor.systemGreen, NSColor.systemBlue)
        case .disconnected:
            return (NSColor.systemRed, NSColor.systemRed)
        case .connecting:
            return (NSColor.systemOrange, NSColor.systemOrange)
        case .error:
            return (NSColor.systemRed, NSColor.systemRed)
        }
    }
    
    private func createAccessibilityValue() -> String {
        let upload = networkMonitor.formatSpeed(networkMonitor.uploadSpeed)
        let download = networkMonitor.formatSpeed(networkMonitor.downloadSpeed)
        
        switch networkMonitor.networkStatus {
        case .connected:
            return "Upload: \(upload), Download: \(download)"
        case .disconnected:
            return "Network disconnected"
        case .connecting:
            return "Connecting to network"
        case .error(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    private func checkPerformance() {
        let now = Date()
        let timeSinceLastCheck = now.timeIntervalSince(lastPerformanceCheck)
        
        if timeSinceLastCheck > 0 {
            let updatesPerSecond = Double(updateCount) / timeSinceLastCheck
            logger.debug("Performance: \(updatesPerSecond) updates/second")
        }
        
        updateCount = 0
        lastPerformanceCheck = now
    }
    
    // MARK: - Event Handling
    @objc private func handleButtonClick() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            togglePopover()
        }
    }
    
    private func togglePopover() {
        if popover?.isShown == true {
            popover?.close()
        } else if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        
        // Status information
        let statusItem = NSMenuItem(title: getStatusText(), action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Current speeds
        let speedsItem = NSMenuItem(title: getSpeedsText(), action: nil, keyEquivalent: "")
        speedsItem.isEnabled = false
        menu.addItem(speedsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        // Display options submenu
        let displayMenu = NSMenu()
        
        let compactItem = NSMenuItem(title: "Compact Display", action: #selector(toggleCompactDisplay), keyEquivalent: "")
        compactItem.target = self
        compactItem.state = showCompactDisplay ? .on : .off
        displayMenu.addItem(compactItem)
        
        let unitsItem = NSMenuItem(title: "Show Units", action: #selector(toggleSpeedUnits), keyEquivalent: "")
        unitsItem.target = self
        unitsItem.state = showSpeedUnits ? .on : .off
        displayMenu.addItem(unitsItem)
        
        let displaySubmenu = NSMenuItem(title: "Display Options", action: nil, keyEquivalent: "")
        displaySubmenu.submenu = displayMenu
        menu.addItem(displaySubmenu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit NetMeter", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Display the menu
        let location = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: location, in: nil)
    }
    
    private func getStatusText() -> String {
        switch networkMonitor.networkStatus {
        case .connected:
            return "Connected via \(networkMonitor.interfaceDescription)"
        case .disconnected:
            return "Network Disconnected"
        case .connecting:
            return "Connecting..."
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func getSpeedsText() -> String {
        let upload = networkMonitor.formatSpeed(networkMonitor.uploadSpeed)
        let download = networkMonitor.formatSpeed(networkMonitor.downloadSpeed)
        return "↓ \(download)  ↑ \(upload)"
    }
    
    // MARK: - Menu Actions
    @objc private func openPreferences() {
        appController.showPreferencesWindow()
    }
    
    @objc private func toggleCompactDisplay() {
        showCompactDisplay.toggle()
        updateDisplay()
    }
    
    @objc private func toggleSpeedUnits() {
        showSpeedUnits.toggle()
        updateDisplay()
    }
    
    @objc private func quitApp() {
        appController.quitApplication()
    }
    
    // MARK: - Cleanup
    private func cleanup() {
        logger.info("Cleaning up StatusBarManager")
        
        timer?.invalidate()
        timer = nil
        
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        
        if let popover = popover {
            popover.close()
            self.popover = nil
        }
        
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}
