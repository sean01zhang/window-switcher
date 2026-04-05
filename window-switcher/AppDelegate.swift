//
//  AppDelegate.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-11-02.
//

import AppKit
import HotKey

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window : NSWindow?
    var hotKey : HotKey?
    let launchAtLoginManager = LaunchAtLoginManager.shared
    
    // Long-lived clients to preserve caches across panels
    let windowClient = WindowClient()
    lazy var streamClient = WindowStreamClient(windowClient.getWindows())
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        ensureAccessibilityPermission()
        ConfigStore.shared.reload()
        launchAtLoginManager.refreshStatus()
        Task {
            await ApplicationIndex.shared.preload()
        }
        applyConfiguredHotKey()
    }
    
    private func applyConfiguredHotKey() {
        let keyCombo = ConfigStore.shared.config.trigger.keyCombo
        if hotKey?.keyCombo == keyCombo {
            return
        }

        hotKey = nil
        hotKey = HotKey(keyCombo: keyCombo)
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.handleTrigger()
                self?.hotKey = nil
            }
        }
    }

    private func reloadConfigForOpen() {
        ConfigStore.shared.reloadIfNeededForOpen()
        applyConfiguredHotKey()
    }

    func handleTrigger() {
        reloadConfigForOpen()
        showWindow()
    }

    func openSwitcherFromMenu() {
        reloadConfigForOpen()
        showWindow()
    }

    func openConfigFileFromMenu() {
        do {
            let fileURL = try ConfigLoader.ensureConfigFileExists()
            if !NSWorkspace.shared.open(fileURL) {
                presentErrorAlert(
                    title: "Unable to Open Config",
                    message: "Window Switcher could not open \(fileURL.path)."
                )
            }
        } catch {
            presentErrorAlert(
                title: "Unable to Open Config",
                message: error.localizedDescription
            )
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(enabled)

            if launchAtLoginManager.needsApproval {
                presentInfoAlert(
                    title: "Approval Needed",
                    message: "Approve Window Switcher in System Settings > General > Login Items to finish enabling launch on startup."
                )
            }
        } catch {
            launchAtLoginManager.refreshStatus()
            presentErrorAlert(
                title: "Unable to Update Launch on Startup",
                message: error.localizedDescription
            )
        }
    }
    
    func showWindow() {
        // Make sure there is only one shown.
        self.closeWindow()
        
        let cp = ContentPanel(
            closeWindow: { [weak self] in self?.closeWindow() },
            windowClient: windowClient,
            streamClient: streamClient,
            triggerShortcut: ConfigStore.shared.config.trigger
        )
        
        window = cp
        cp.makeKeyAndOrderFront(nil)
        cp.makeKey()
    }
    
    func closeWindow() {
        if let w = window {
            w.close()
            window = nil
            applyConfiguredHotKey()
        }
    }

    func refreshWindows() {
        windowClient.refresh()

        Task { [windowClient, streamClient] in
            do {
                try await streamClient.refresh(windowClient.getWindows())
            } catch {
                print("error: refresh window previews: \(error)")
            }
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

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
