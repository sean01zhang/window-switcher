//
//  window_switcherApp.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI

// periphery:ignore
var activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
    reason: "Prevent App Nap to preserve responsiveness")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyMonitor: Any?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Get window and make it borderless.
        if let window = NSApplication.shared.windows.first {
//            window.level = .floating
            window.backgroundColor = .clear
            window.styleMask = [.borderless, .fullSizeContentView]
        }
        
        NSApp.setActivationPolicy(.accessory)
        
        registerHotKey()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        unregisterHotKey()
    }

    private func registerHotKey() {
        let mask: NSEvent.ModifierFlags = [.option]
        let keyCode = 48 // KeyCode for Tab
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(mask),
                  event.keyCode == keyCode else { return }

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
        WindowGroup(id: "main") {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                    NSApplication.shared.hide(self)
                }
        }
        
    }
}
