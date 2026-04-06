import AppKit
import Observation

enum PermissionStatus: Equatable {
    case granted
    case denied
    case unknown
}

@MainActor
@Observable
final class PermissionManager {
    static let shared = PermissionManager()

    private let client: any PermissionClient
    private let onboardingStore: any OnboardingStore

    private(set) var accessibilityStatus: PermissionStatus = .unknown
    private(set) var screenRecordingStatus: PermissionStatus = .unknown

    var allGranted: Bool {
        accessibilityStatus == .granted && screenRecordingStatus == .granted
    }

    var requiredPermissionsGranted: Bool {
        accessibilityStatus == .granted
    }

    var hasCompletedOnboarding: Bool {
        get { onboardingStore.hasCompletedOnboarding }
        set { onboardingStore.hasCompletedOnboarding = newValue }
    }

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    init(
        client: any PermissionClient = SystemPermissionClient(),
        onboardingStore: any OnboardingStore = UserDefaultsOnboardingStore()
    ) {
        self.client = client
        self.onboardingStore = onboardingStore
        refreshAll()
        if !hasCompletedOnboarding && requiredPermissionsGranted {
            hasCompletedOnboarding = true
        }
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

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
