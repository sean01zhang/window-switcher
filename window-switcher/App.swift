//
//  App.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI
import AppKit

// periphery:ignore
var activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Prevent App Nap to preserve responsiveness")

let versionIdentifier = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

@main
struct window_switcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var launchAtLoginManager = LaunchAtLoginManager.shared
    
    var body: some Scene {
        MenuBarExtra("Windows", systemImage: "macwindow") {
            let configStore = ConfigStore.shared
            HStack(spacing: 10) {
                Text("Window Switcher (v\(versionIdentifier))")
                Button("Report an Issue...") {
                    guard let url = URL(string: "https://github.com/sean01zhang/window-switcher/issues") else {
                        return
                    }
                    NSWorkspace.shared.open(url)
                }
                Divider()
                if let shortcut = configStore.config.trigger.menuShortcut {
                    Button("Open Switcher") {
                        appDelegate.openSwitcherFromMenu()
                    }
                    .keyboardShortcut(shortcut)
                } else {
                    Button("Open Switcher (\(configStore.config.trigger.displayString))") {
                        appDelegate.openSwitcherFromMenu()
                    }
                }
                Button("Open Config...") {
                    appDelegate.openConfigFileFromMenu()
                }
                Toggle(
                    "Launch on Startup",
                    isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { appDelegate.setLaunchAtLoginEnabled($0) }
                    )
                )
                Button("Refresh Windows") {
                    appDelegate.refreshWindows()
                }.keyboardShortcut("r")
                if launchAtLoginManager.needsApproval {
                    Text("Waiting for Login Items approval")
                        .foregroundStyle(.secondary)
                }
                Divider()
                Button("Quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q")
            }.frame(maxWidth: .infinity)
        }
    }
}
