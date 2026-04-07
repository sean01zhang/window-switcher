import Observation

@MainActor
@Observable
final class MenuBarExtraViewModel {
    private let launchAtLoginClient: LaunchAtLoginClient
    private let permissionStore: PermissionStore

    private(set) var launchAtLoginEnabled = false
    private(set) var launchAtLoginNeedsApproval = false

    init(
        launchAtLoginClient: LaunchAtLoginClient,
        permissionStore: PermissionStore
    ) {
        self.launchAtLoginClient = launchAtLoginClient
        self.permissionStore = permissionStore
        refresh()
    }

    func refresh() {
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

    func setLaunchAtLoginEnabled(_ enabled: Bool) throws -> Bool {
        try launchAtLoginClient.setEnabled(enabled)
        refresh()
        return launchAtLoginNeedsApproval
    }
}
