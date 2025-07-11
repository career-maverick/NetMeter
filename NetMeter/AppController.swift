//
//  AppController.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import SwiftUI
import Cocoa
import os.log
import Combine

// MARK: - App Controller Protocol
protocol AppControllerProtocol: ObservableObject {
    var networkMonitor: NetworkMonitor { get }
    func showPreferencesWindow()
    func hidePreferencesWindow()
    func quitApplication()
}

// MARK: - App Controller
class AppController: NSObject, ObservableObject, AppControllerProtocol {
    // MARK: - Published Properties
    @Published var isPreferencesWindowVisible = false
    @Published var lastError: Error?
    
    // MARK: - Dependencies
    let networkMonitor: NetworkMonitor
    private var statusBarManager: StatusBarManager?
    private var preferencesWindowController: NSWindowController?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.netmeter.app", category: "AppController")
    private var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    override init() {
        self.networkMonitor = NetworkMonitor()
        super.init()
        setupStatusBarManager()
        setupNotificationObservers()
        setupErrorHandling()
        logger.info("AppController initialized successfully")
    }
    
    init(networkMonitor: NetworkMonitor) {
        self.networkMonitor = networkMonitor
        super.init()
        setupStatusBarManager()
        setupNotificationObservers()
        setupErrorHandling()
        logger.info("AppController initialized successfully")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    func showPreferencesWindow() {
        logger.info("Showing preferences window")
        
        // Create window on-demand if it doesn't exist
        if preferencesWindowController == nil {
            createPreferencesWindow()
        }
        
        // Show window and bring to front
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            self.isPreferencesWindowVisible = true
        }
    }
    
    func hidePreferencesWindow() {
        logger.info("Hiding preferences window")
        
        preferencesWindowController?.close()
        
        DispatchQueue.main.async {
            self.isPreferencesWindowVisible = false
        }
    }
    
    func quitApplication() {
        logger.info("Quitting application")
        
        // Clean up resources
        cleanup()
        
        // Quit the application
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Private Methods
    private func setupStatusBarManager() {
        statusBarManager = StatusBarManager(networkMonitor: networkMonitor, appController: self)
        logger.info("Status bar manager initialized")
    }
    
    private func setupNotificationObservers() {
        // Observe preferences window requests
        let preferencesObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("showPreferencesWindow:"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showPreferencesWindow()
        }
        notificationObservers.append(preferencesObserver)
        
        // Observe quit requests
        let quitObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("quitApplication:"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.quitApplication()
        }
        notificationObservers.append(quitObserver)
        
        // Observe network errors
        let networkErrorObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("networkError:"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.object as? Error {
                self?.handleNetworkError(error)
            }
        }
        notificationObservers.append(networkErrorObserver)
    }
    
    private func setupErrorHandling() {
        // Monitor network monitor errors
        networkMonitor.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleNetworkError(error)
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkError(_ error: Error) {
        logger.error("Network error occurred: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.lastError = error
            
            // Show user-friendly error message
            self.showErrorAlert(error: error)
        }
    }
    
    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Network Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Retry")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Retry network monitoring
            networkMonitor.restartMonitoring()
        }
    }
    
    private func createPreferencesWindow() {
        logger.info("Creating preferences window")
        
        // Create a standard window with proper sizing
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        window.title = "NetMeter Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Create settings view with dependency injection
        let settingsView = SettingsView(networkMonitor: networkMonitor, appController: self)
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Set content
        window.contentViewController = hostingController
        
        // Create controller
        preferencesWindowController = NSWindowController(window: window)
        
        logger.info("Preferences window created successfully")
    }
    
    private func cleanup() {
        logger.info("Cleaning up AppController resources")
        
        // Remove notification observers
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // Close preferences window
        preferencesWindowController?.close()
        preferencesWindowController = nil
        
        // Clean up status bar manager
        statusBarManager = nil
        
        // Cancel any pending operations
        cancellables.removeAll()
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - NSWindowDelegate
extension AppController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === preferencesWindowController?.window else { return }
        
        DispatchQueue.main.async {
            self.isPreferencesWindowVisible = false
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow the window to close, but update our state
        DispatchQueue.main.async {
            self.isPreferencesWindowVisible = false
        }
        return true
    }
}

// MARK: - Error Handling Extensions
extension AppController {
    func handleUnexpectedError(_ error: Error, context: String) {
        logger.error("Unexpected error in \(context): \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.lastError = error
        }
    }
    
    func clearLastError() {
        DispatchQueue.main.async {
            self.lastError = nil
        }
    }
}

// MARK: - Testing Support
#if DEBUG
extension AppController {
    func resetForTesting() {
        cleanup()
        setupStatusBarManager()
        setupNotificationObservers()
        setupErrorHandling()
    }
}
#endif
