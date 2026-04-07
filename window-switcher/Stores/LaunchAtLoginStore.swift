import Observation

@MainActor
@Observable
final class LaunchAtLoginStore {
    private let client: any LaunchAtLoginClient

    private(set) var isEnabled = false
    private(set) var needsApproval = false

    init(client: any LaunchAtLoginClient = SystemLaunchAtLoginClient()) {
        self.client = client
        refreshStatus()
    }

    func refreshStatus() {
        switch client.status() {
        case .enabled:
            isEnabled = true
            needsApproval = false
        case .requiresApproval:
            isEnabled = true
            needsApproval = true
        case .disabled:
            isEnabled = false
            needsApproval = false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        try client.setEnabled(enabled)
        refreshStatus()
    }
}
