import AppKit
import Observation

enum PermissionStatus: Equatable {
    case granted
    case denied
}

@MainActor
@Observable
final class PermissionManager {
    static let shared = PermissionManager()

    private let client: any PermissionClient

    private(set) var accessibilityStatus: PermissionStatus
    private(set) var screenRecordingStatus: PermissionStatus

    var allGranted: Bool {
        accessibilityStatus == .granted && screenRecordingStatus == .granted
    }

    var requiredPermissionsGranted: Bool {
        accessibilityStatus == .granted
    }

    var shouldShowOnboarding: Bool {
        accessibilityStatus != .granted
    }

    init(client: any PermissionClient = SystemPermissionClient()) {
        self.client = client
        self.accessibilityStatus = client.accessibilityStatus()
        self.screenRecordingStatus = client.screenRecordingStatus()
    }

    // MARK: - Accessibility

    func refreshAccessibility() {
        let newStatus = client.accessibilityStatus()
        if accessibilityStatus != newStatus {
            accessibilityStatus = newStatus
        }
    }

    func requestAccessibility() {
        client.requestAccessibility()
        refreshAccessibility()
    }

    func openAccessibilitySettings() {
        client.openAccessibilitySettings()
    }

    // MARK: - Screen Recording

    func refreshScreenRecording() {
        let newStatus = client.screenRecordingStatus()
        if screenRecordingStatus != newStatus {
            screenRecordingStatus = newStatus
        }
    }

    func requestScreenRecording() {
        client.requestScreenRecording()
        refreshScreenRecording()
    }

    func openScreenRecordingSettings() {
        client.openScreenRecordingSettings()
    }

    // MARK: - Aggregate

    func refreshAll() {
        refreshAccessibility()
        refreshScreenRecording()
    }
}
