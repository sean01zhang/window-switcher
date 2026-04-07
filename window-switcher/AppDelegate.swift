//
//  AppDelegate.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-11-02.
//

import AppKit
import HotKey
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    var hotKey: HotKey?
    var onboardingWindow: NSWindow?
    var onboardingAppDidBecomeActiveObserver: NSObjectProtocol?
    var lastKnownOnboardingAccessibilityGranted = false

    let configStore = ConfigStore()
    let launchAtLoginClient = LaunchAtLoginClient()
    let permissionStore = PermissionStore()
    let installedApplicationsClient = InstalledApplicationsClient()
    let workspaceClient: any WorkspaceClient = SystemWorkspaceClient()
    let appRuntimeClient = AppRuntimeClient.live

    let windowClient = WindowClient()
    lazy var streamClient = WindowStreamClient(windowClient.getWindows())

    deinit {
        if let onboardingAppDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(onboardingAppDidBecomeActiveObserver)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        permissionStore.refreshAll()
        reloadConfig()

        Task {
            await installedApplicationsClient.preload()
        }

        DispatchQueue.main.async { [weak self] in
            self?.showOnboardingIfNeeded()
        }
    }

    func openSwitcherFromMenu() {
        _ = handleTrigger()
    }

    func openConfigFileFromMenu() {
        do {
            let fileURL = try ConfigLoader.ensureConfigFileExists()
            if !workspaceClient.openURL(fileURL) {
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

    func reloadConfigFromMenu() {
        reloadConfig()
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
        if let onboardingWindow {
            refreshOnboardingPermissions()
            onboardingWindow.makeKeyAndOrderFront(nil)
            onboardingWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        hotKey = nil
        lastKnownOnboardingAccessibilityGranted = permissionStore.requiredPermissionsGranted

        let onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        onboardingWindow.delegate = self
        onboardingWindow.contentView = NSHostingView(
            rootView: OnboardingView(
                permissionStore: permissionStore,
                onDismiss: { [weak onboardingWindow] in onboardingWindow?.close() },
                onRelaunch: { [weak self] in
                    guard let self else {
                        return
                    }

                    do {
                        try self.appRuntimeClient.relaunch()
                    } catch {
                        self.presentErrorAlert(
                            title: "Unable to Relaunch",
                            message: error.localizedDescription
                        )
                    }
                }
            )
        )
        onboardingWindow.title = "Welcome to Window Switcher"
        onboardingWindow.center()
        onboardingWindow.isReleasedWhenClosed = false
        self.onboardingWindow = onboardingWindow

        onboardingAppDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.onboardingWindow?.isVisible == true else {
                    return
                }

                self.refreshOnboardingPermissions()
            }
        }

        refreshOnboardingPermissions()
        onboardingWindow.makeKeyAndOrderFront(nil)
        onboardingWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    private func handleTrigger() -> Bool {
        guard ensureAccessibility() else {
            return false
        }

        showWindow()
        return true
    }

    private func applyConfiguredHotKey() {
        let keyCombo = configStore.config.trigger.keyCombo
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

    private func reloadConfig() {
        configStore.reload()
        applyConfiguredHotKey()
    }

    private func handleHotKeyTrigger() {
        if handleTrigger() {
            hotKey = nil
        }
    }

    private func ensureAccessibility() -> Bool {
        let hadAccessibility = permissionStore.requiredPermissionsGranted
        permissionStore.refreshAccessibility()

        if !hadAccessibility && permissionStore.requiredPermissionsGranted {
            refreshWindows()
        }

        guard permissionStore.requiredPermissionsGranted else {
            showOnboarding()
            return false
        }

        return true
    }

    private func showWindow() {
        closeWindow()

        let config = configStore.config
        let panel = ContentPanel(
            closeWindow: { [weak self] in self?.closeWindow() },
            windowClient: windowClient,
            streamClient: streamClient,
            installedApplicationsClient: installedApplicationsClient,
            workspaceClient: workspaceClient,
            triggerShortcut: config.trigger,
            quickSwitch: config.quickSwitch,
            navigation: config.navigation,
            resultListItem: config.resultListItem
        )

        window = panel
        panel.makeKeyAndOrderFront(nil)
        panel.makeKey()
    }

    private func closeWindow() {
        if let window {
            window.close()
            self.window = nil
            applyConfiguredHotKey()
        }
    }

    private func dismissOnboarding() {
        onboardingWindow = nil

        if let onboardingAppDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(onboardingAppDidBecomeActiveObserver)
            self.onboardingAppDidBecomeActiveObserver = nil
        }

        let hadAccessibility = permissionStore.requiredPermissionsGranted
        permissionStore.refreshAccessibility()
        if !hadAccessibility && permissionStore.requiredPermissionsGranted {
            refreshWindows()
        }

        if window == nil {
            applyConfiguredHotKey()
        }
    }

    private func showOnboardingIfNeeded() {
        guard permissionStore.shouldShowOnboarding else {
            return
        }

        showOnboarding()
    }

    private func refreshOnboardingPermissions() {
        let hadAccessibility = lastKnownOnboardingAccessibilityGranted
        permissionStore.refreshAll()

        let hasAccessibility = permissionStore.requiredPermissionsGranted
        lastKnownOnboardingAccessibilityGranted = hasAccessibility

        if !hadAccessibility && hasAccessibility {
            refreshWindows()
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

    func presentLaunchAtLoginApprovalAlert() {
        presentInfoAlert(
            title: "Approval Needed",
            message: "Approve Window Switcher in System Settings > General > Login Items to finish enabling launch on startup."
        )
    }

    func presentLaunchAtLoginUpdateError(_ error: Error) {
        presentErrorAlert(
            title: "Unable to Update Launch on Startup",
            message: error.localizedDescription
        )
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === onboardingWindow else {
            return
        }

        refreshOnboardingPermissions()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === onboardingWindow else {
            return
        }

        dismissOnboarding()
    }
}
