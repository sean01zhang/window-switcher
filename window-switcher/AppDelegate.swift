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
    var onboardingWindow: OnboardingWindow?
    let launchAtLoginManager = LaunchAtLoginManager.shared
    let permissionManager = PermissionManager.shared

    // Long-lived clients to preserve caches across panels
    let windowClient = WindowClient()
    lazy var streamClient = WindowStreamClient(windowClient.getWindows())
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        permissionManager.refreshAll()
        ConfigStore.shared.reload()
        launchAtLoginManager.refreshStatus()
        Task {
            await ApplicationIndex.shared.preload()
        }
        applyConfiguredHotKey()

        if permissionManager.shouldShowOnboarding {
            showOnboarding()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let previousAccessibility = permissionManager.accessibilityStatus
        permissionManager.refreshAll()

        if previousAccessibility != .granted && permissionManager.accessibilityStatus == .granted {
            refreshWindows()
        }
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
                self?.handleHotKeyTrigger()
            }
        }
    }

    private func reloadConfigForOpen() {
        ConfigStore.shared.reloadIfNeededForOpen()
        applyConfiguredHotKey()
    }

    @discardableResult
    func handleTrigger() -> Bool {
        reloadConfigForOpen()
        guard ensureAccessibility() else { return false }
        showWindow()
        return true
    }

    private func handleHotKeyTrigger() {
        if handleTrigger() {
            hotKey = nil
        }
    }

    func openSwitcherFromMenu() {
        _ = handleTrigger()
    }

    private func ensureAccessibility() -> Bool {
        permissionManager.refreshAccessibility()
        guard permissionManager.requiredPermissionsGranted else {
            showOnboarding()
            return false
        }
        return true
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
        let config = ConfigStore.shared.config
        
        let cp = ContentPanel(
            closeWindow: { [weak self] in self?.closeWindow() },
            windowClient: windowClient,
            streamClient: streamClient,
            triggerShortcut: config.trigger,
            quickSwitch: config.quickSwitch,
            navigation: config.navigation,
            resultListItem: config.resultListItem
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

    func showOnboarding() {
        guard onboardingWindow == nil else {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        hotKey = nil
        let window = OnboardingWindow(permissionManager: permissionManager, onDismiss: { [weak self] in
            self?.dismissOnboarding()
        })
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissOnboarding() {
        onboardingWindow = nil
        if window == nil {
            applyConfiguredHotKey()
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
