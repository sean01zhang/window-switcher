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

@main
struct window_switcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Windows", systemImage: "macwindow") {
            MenuBarExtraContentView(
                versionIdentifier: appDelegate.appRuntimeClient.versionIdentifier(),
                appDelegate: appDelegate,
                configStore: appDelegate.configStore,
                permissionStore: appDelegate.permissionStore,
                launchAtLoginStore: appDelegate.launchAtLoginStore,
                workspaceClient: appDelegate.workspaceClient,
                appRuntimeClient: appDelegate.appRuntimeClient
            )
        }
    }
}
