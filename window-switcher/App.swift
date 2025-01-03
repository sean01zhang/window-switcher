//
//  App.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyMonitor: Any?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Get window and make it borderless.
        if let window = NSApplication.shared.windows.first {
            window.level = .floating
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
        // TODO: Use a more modern approach to key listening
        let mask: NSEvent.ModifierFlags = [.option]
        let keyCode = kVK_Tab
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
        WindowGroup() {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                    NSApplication.shared.hide(self)
                }
        }
        
    }
}
