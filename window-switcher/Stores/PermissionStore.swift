import AppKit
import Observation

@MainActor
@Observable
final class PermissionStore {
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

    func refreshScreenRecording() {
        let newStatus = client.screenRecordingStatus()
        if screenRecordingStatus != newStatus {
            screenRecordingStatus = newStatus
        }
    }

    func requestScreenRecording() {
        client.requestScreenRecording()
        refreshScreenRecording()
        if screenRecordingStatus != .granted {
            client.openScreenRecordingSettings()
        }
    }

    func openScreenRecordingSettings() {
        client.openScreenRecordingSettings()
    }

    func refreshAll() {
        refreshAccessibility()
        refreshScreenRecording()
    }
}
