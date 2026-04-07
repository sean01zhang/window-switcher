//
//  AppDelegate.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-11-02.
//

import AppKit
import HotKey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var hotKey: HotKey?

    let configStore = ConfigStore()
    let launchAtLoginClient = LaunchAtLoginClient()
    let permissionStore = PermissionStore()
    let installedApplicationsClient = InstalledApplicationsClient()
    let workspaceClient: any WorkspaceClient = SystemWorkspaceClient()
    let appRuntimeClient = AppRuntimeClient.live

    let windowClient = WindowClient()
    lazy var streamClient = WindowStreamClient(windowClient.getWindows())

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        permissionStore.refreshAll()
        reloadConfig()

        Task {
            await installedApplicationsClient.preload()
        }

        DispatchQueue.main.async { [weak self] in
            if self?.permissionStore.shouldShowOnboarding == true {
                self?.showWindow()
            }
        }
    }

    func openSwitcherFromMenu() {
        routeTrigger()
    }
    
    func reloadConfigFromMenu() {
        reloadConfig()
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

    private func applyConfiguredHotKey() {
        let keyCombo = configStore.config.trigger.keyCombo
        if hotKey?.keyCombo == keyCombo {
            return
        }

        hotKey = nil
        hotKey = HotKey(keyCombo: keyCombo)
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.routeTrigger()
            }
        }
    }

    private func reloadConfig() {
        configStore.reload()
        applyConfiguredHotKey()
    }

    private func routeTrigger() {
        if accessibilityWasGranted() {
            refreshWindows()
        }
        
        toggleWindow()
    }

    private func showWindow() {
        var newWindow: NSWindow
        if permissionStore.shouldShowOnboarding {
            newWindow = OnboardingPanel(
                permissionStore: permissionStore,
                onAccessibilityGranted: { [weak self] in
                    self?.refreshWindows()
                },
                onClose: { [weak self] in
                    self?.window = nil
                    self?.applyConfiguredHotKey()
                }
            )
        } else {
            let config = configStore.config
            newWindow = ContentPanel(
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
        }
        
        hotKey = nil
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.makeKey()
    }

    private func toggleWindow() {
        if window != nil {
            closeWindow()
        } else {
            showWindow()
        }
    }

    private func closeWindow() {
        guard let window else {
            return
        }

        window.close()
        self.window = nil
        applyConfiguredHotKey()
    }

    private func accessibilityWasGranted() -> Bool {
        let hadAccessibility = permissionStore.requiredPermissionsGranted
        permissionStore.refreshAccessibility()
        return !hadAccessibility && permissionStore.requiredPermissionsGranted
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

}
