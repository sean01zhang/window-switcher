import Foundation
import ServiceManagement
import Observation

@MainActor
@Observable
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private(set) var isEnabled = false
    private(set) var needsApproval = false

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            needsApproval = false
        case .requiresApproval:
            isEnabled = true
            needsApproval = true
        case .notRegistered, .notFound:
            isEnabled = false
            needsApproval = false
        @unknown default:
            isEnabled = false
            needsApproval = false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }

        refreshStatus()
    }
}
