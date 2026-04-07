import SwiftUI

struct MenuBarExtraContentView: View {
    let versionIdentifier: String
    let appDelegate: AppDelegate
    let configStore: ConfigStore
    let permissionStore: PermissionStore
    let launchAtLoginStore: LaunchAtLoginStore
    let workspaceClient: any WorkspaceClient
    let appRuntimeClient: AppRuntimeClient

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
                    get: { launchAtLoginStore.isEnabled },
                    set: { appDelegate.setLaunchAtLoginEnabled($0) }
                )
            )
            if launchAtLoginStore.needsApproval {
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
}
