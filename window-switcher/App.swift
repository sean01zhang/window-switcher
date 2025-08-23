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
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var statusBarItem: NSStatusItem?
    var mainWindow: NSWindow?
    private var isHotkeyActionInProgress = false
    private var isOverlayVisible = false

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
    
    private func showWindowSwitcher() {
        guard !isOverlayVisible else { return }
        self.mainWindow?.styleMask.update(with: .titled)
        self.mainWindow?.makeKeyAndOrderFront(nil)
        self.mainWindow?.styleMask.remove(.titled)
        self.activateApp()
        isOverlayVisible = true
    }

    private func hideWindowSwitcher() {
        guard isOverlayVisible else { return }
        NSApp.hide(nil)
        isOverlayVisible = false
    }

    @objc func activateOverlay(_ sender: NSStatusBarButton) {
        if isOverlayVisible {
            hideWindowSwitcher()
        } else {
            showWindowSwitcher()
        }
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
        NotificationCenter.default.addObserver(forName: NSApplication.didHideNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.isOverlayVisible = false
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        unregisterHotKey()
    }

    private func registerHotKey() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: mask,
                                     callback: { _, type, event, userInfo in
            guard type == .keyDown else {
                return Unmanaged.passRetained(event)
            }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
            if keyCode == kVK_Tab &&
                flags.intersection(.deviceIndependentFlagsMask) == .option {
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo!).takeUnretainedValue()
                var shouldHandle = false
                DispatchQueue.main.sync {
                    if !delegate.isHotkeyActionInProgress {
                        delegate.isHotkeyActionInProgress = true
                        shouldHandle = true
                    }
                }
                if shouldHandle {
                    DispatchQueue.main.async {
                        if delegate.isOverlayVisible {
                            delegate.hideWindowSwitcher()
                        } else {
                            delegate.showWindowSwitcher()
                        }
                        delegate.isHotkeyActionInProgress = false
                    }
                }
                return nil
            }
            return Unmanaged.passRetained(event)
        }, userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    private func unregisterHotKey() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            self.runLoopSource = nil
            self.eventTap = nil
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
