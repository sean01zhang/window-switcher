//
//  App.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI
import AppKit
import Carbon

// periphery:ignore
var activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Prevent App Nap to preserve responsiveness")

let versionIdentifier = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

extension Notification.Name {
    static let restartWindowSwitcher = Notification.Name("restartWindowSwitcher")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyMonitor: Any?
    private var statusBarItem: NSStatusItem?
    var mainWindow: NSWindow?

    private func ensureAccessibilityPermission() {
        if !AccessibilityPermissions.ensurePrompt() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Window Switcher needs accessibility access to display open windows."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                AccessibilityPermissions.openSystemSettings()
            }
            NSApp.terminate(nil)
        }
    }
    
    func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.target = self
            button.title = "WS"
        }
        
        let menu = NSMenu()
        let topicItem = NSMenuItem(title: "Window Switcher (v\(versionIdentifier))", action: nil, keyEquivalent: "")
        let gitHubMenuItem = NSMenuItem(title: "Report an Issue", action: #selector(openGitHub), keyEquivalent: "")
        let activateMenuItem = NSMenuItem(title: "Open Switcher", action: #selector(activateOverlay(_:)), keyEquivalent: "\t")
        activateMenuItem.keyEquivalentModifierMask = .option
        let refreshMenuItem = NSMenuItem(title: "Refresh Windows", action: #selector(refreshWindowsClicked(_:)), keyEquivalent: "r")
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
       
        menu.addItem(topicItem)
        menu.addItem(gitHubMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(activateMenuItem)
        menu.addItem(refreshMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitMenuItem)
        
        statusBarItem?.menu = menu
    }
    
    @objc func activateOverlay(_ sender: NSStatusBarButton) {
        self.mainWindow?.styleMask.update(with: .titled)
        self.mainWindow?.makeKeyAndOrderFront(nil)
        self.mainWindow?.styleMask.remove(.titled)
        self.activateApp()
    }
    
    @objc func refreshWindowsClicked(_ sender: NSStatusBarButton) {
        NotificationCenter.default.post(name: .restartWindowSwitcher, object: nil)
    }
    
    @objc func openGitHub(_ sender: NSStatusBarButton) {
        guard let url = URL(string: "https://github.com/sean01zhang/window-switcher/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ensureAccessibilityPermission()

        // Get window and make it borderless.
        if let window = NSApplication.shared.windows.first {
            window.level = .popUpMenu
            window.backgroundColor = .clear
            window.styleMask = [.borderless]
            window.center()
            self.mainWindow = window
        }
        
        NSApp.setActivationPolicy(.accessory)
        registerHotKey()
        setupStatusBar()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        unregisterHotKey()
    }

    private func registerHotKey() {
        // TODO: Use a more modern approach to key listening
        let mask: NSEvent.ModifierFlags = [.option]
        let keyCode = kVK_Tab
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(mask),
                  event.keyCode == keyCode else { return }
            
            // TODO: Find a better way to deal with focus problems
            self?.mainWindow?.styleMask.update(with: .titled)
            self?.mainWindow?.makeKeyAndOrderFront(nil)
            self?.mainWindow?.styleMask.remove(.titled)
            self?.activateApp()
        }
    }

    private func unregisterHotKey() {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotKeyMonitor = nil
        }
    }

    private func activateApp() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct window_switcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup() {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                    NSApplication.shared.hide(self)
                }
        }
    }
}
