import SwiftUI

struct MenuBarExtraContentView: View {
    let versionIdentifier: String
    let appDelegate: AppDelegate
    let configStore: ConfigStore
    let permissionStore: PermissionStore
    let launchAtLoginClient: LaunchAtLoginClient
    let workspaceClient: any WorkspaceClient
    let appRuntimeClient: AppRuntimeClient
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginNeedsApproval = false

    init(
        versionIdentifier: String,
        appDelegate: AppDelegate,
        configStore: ConfigStore,
        permissionStore: PermissionStore,
        launchAtLoginClient: LaunchAtLoginClient,
        workspaceClient: any WorkspaceClient,
        appRuntimeClient: AppRuntimeClient
        ) {
        self.versionIdentifier = versionIdentifier
        self.appDelegate = appDelegate
        self.configStore = configStore
        self.permissionStore = permissionStore
        self.launchAtLoginClient = launchAtLoginClient
        self.workspaceClient = workspaceClient
        self.appRuntimeClient = appRuntimeClient
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("Window Switcher (v\(versionIdentifier))")
            Button("Report an Issue...") {
                guard let url = URL(string: "https://github.com/sean01zhang/window-switcher/issues") else {
                    return
                }
                _ = workspaceClient.openURL(url)
            }
            if !permissionStore.allGranted {
                Divider()
                permissionStatusSection
                permissionActionSection
            }
            Divider()
            openSwitcherButton
            Button("Refresh Windows") {
                appDelegate.refreshWindows()
            }
            .keyboardShortcut("r")
            Toggle(
                "Launch on Startup",
                isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: updateLaunchAtLogin
                )
            )
            if launchAtLoginNeedsApproval {
                Text("Waiting for Login Items approval")
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button("Open Config...") {
                appDelegate.openConfigFileFromMenu()
            }
            Button("Reload Config") {
                appDelegate.reloadConfigFromMenu()
            }
            Button("Quit", role: .destructive) {
                appRuntimeClient.terminate()
            }
            .keyboardShortcut("q")
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            refreshMenuState()
        }
    }

    @ViewBuilder
    private var permissionStatusSection: some View {
        if !permissionStore.requiredPermissionsGranted {
            Label {
                Text("Accessibility Required")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(.yellow)
        } else if permissionStore.screenRecordingStatus != .granted {
            Label {
                Text("Previews Optional")
            } icon: {
                Image(systemName: "photo.on.rectangle.angled")
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var permissionActionSection: some View {
        if permissionStore.accessibilityStatus != .granted {
            Button("Grant Accessibility Access...") {
                permissionStore.openAccessibilitySettings()
            }
        }
        if permissionStore.screenRecordingStatus != .granted {
            Button("Grant Screen Recording Access...") {
                permissionStore.openScreenRecordingSettings()
            }
        }
    }

    @ViewBuilder
    private var openSwitcherButton: some View {
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
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginClient.setEnabled(enabled)
            refreshMenuState()
            if launchAtLoginNeedsApproval {
                appDelegate.presentLaunchAtLoginApprovalAlert()
            }
        } catch {
            refreshMenuState()
            appDelegate.presentLaunchAtLoginUpdateError(error)
        }
    }

    private func refreshMenuState() {
        permissionStore.refreshAll()

        switch launchAtLoginClient.status() {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginNeedsApproval = false
        case .requiresApproval:
            launchAtLoginEnabled = true
            launchAtLoginNeedsApproval = true
        case .disabled:
            launchAtLoginEnabled = false
            launchAtLoginNeedsApproval = false
        }
    }
}
