import Testing
#if canImport(window_switcher_dev)
@testable import window_switcher_dev
#else
@testable import window_switcher
#endif

@MainActor
struct PermissionManagerTests {
    @Test func requiredPermissionsCompleteOnboardingDuringInitialization() {
        let client = StubPermissionClient(
            accessibilityStatus: .granted,
            screenRecordingStatus: .denied
        )
        let onboardingStore = StubOnboardingStore(hasCompletedOnboarding: false)

        let manager = PermissionManager(
            client: client,
            onboardingStore: onboardingStore
        )

        #expect(manager.accessibilityStatus == .granted)
        #expect(manager.screenRecordingStatus == .denied)
        #expect(manager.requiredPermissionsGranted)
        #expect(onboardingStore.hasCompletedOnboarding)
        #expect(!manager.shouldShowOnboarding)
    }

    @Test func permissionRequestsAndCompletionUseInjectedDependencies() {
        let client = StubPermissionClient(
            accessibilityStatus: .denied,
            screenRecordingStatus: .denied
        )
        client.onRequestAccessibility = {
            client.accessibilityStatusValue = .granted
        }
        client.onRequestScreenRecording = {
            client.screenRecordingStatusValue = .granted
        }
        let onboardingStore = StubOnboardingStore(hasCompletedOnboarding: false)

        let manager = PermissionManager(
            client: client,
            onboardingStore: onboardingStore
        )

        manager.requestAccessibility()
        manager.requestScreenRecording()
        manager.completeOnboarding()

        #expect(client.requestAccessibilityCallCount == 1)
        #expect(client.requestScreenRecordingCallCount == 1)
        #expect(manager.accessibilityStatus == .granted)
        #expect(manager.screenRecordingStatus == .granted)
        #expect(onboardingStore.hasCompletedOnboarding)
    }
}

private final class StubPermissionClient: PermissionClient {
    var accessibilityStatusValue: PermissionStatus
    var screenRecordingStatusValue: PermissionStatus
    var requestAccessibilityCallCount = 0
    var requestScreenRecordingCallCount = 0
    var onRequestAccessibility: (() -> Void)?
    var onRequestScreenRecording: (() -> Void)?

    init(accessibilityStatus: PermissionStatus, screenRecordingStatus: PermissionStatus) {
        self.accessibilityStatusValue = accessibilityStatus
        self.screenRecordingStatusValue = screenRecordingStatus
    }

    func accessibilityStatus() -> PermissionStatus {
        accessibilityStatusValue
    }

    func requestAccessibility() {
        requestAccessibilityCallCount += 1
        onRequestAccessibility?()
    }

    func openAccessibilitySettings() {}

    func screenRecordingStatus() -> PermissionStatus {
        screenRecordingStatusValue
    }

    func requestScreenRecording() {
        requestScreenRecordingCallCount += 1
        onRequestScreenRecording?()
    }

    func openScreenRecordingSettings() {}
}

private final class StubOnboardingStore: OnboardingStore {
    var hasCompletedOnboarding: Bool

    init(hasCompletedOnboarding: Bool) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
