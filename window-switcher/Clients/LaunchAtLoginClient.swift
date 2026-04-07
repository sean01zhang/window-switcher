import Foundation
import ServiceManagement

enum LaunchAtLoginStatus {
    case enabled
    case requiresApproval
    case disabled
}

protocol LaunchAtLoginClient {
    func status() -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) throws
}

struct SystemLaunchAtLoginClient: LaunchAtLoginClient {
    func status() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
