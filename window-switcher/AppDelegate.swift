//
//  AppDelegate.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-11-02.
//

import AppKit
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var window : NSWindow?
    var hotKey : HotKey?
    
    // Long-lived clients to preserve caches across panels
    let windowClient = WindowClient()
    lazy var streamClient = WindowStreamClient(windowClient.getWindows())
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        ensureAccessibilityPermission()
        setupHotKey()
    }
    
    private func setupHotKey() {
        hotKey = HotKey(key: .tab, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }
    }
    
    func toggleWindow() {
        if window == nil {
            showWindow()
        } else {
            closeWindow()
        }
    }
    
    func showWindow() {
        // Make sure there is only one shown.
        self.closeWindow()
        
        let cp = ContentPanel(
            closeWindow: { [weak self] in self?.closeWindow() },
            windowClient: windowClient,
            streamClient: streamClient
        )
        
        window = cp
        cp.makeKeyAndOrderFront(nil)
        cp.makeKey()
    }
    
    func closeWindow() {
        if let w = window {
            w.close()
            window = nil
        }
    }

    private func ensureAccessibilityPermission() {
        if !A11yClient.ensurePrompt() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Window Switcher needs accessibility access to display open windows."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                A11yClient.openSystemSettings()
            }
            NSApp.terminate(nil)
        }
    }
}
