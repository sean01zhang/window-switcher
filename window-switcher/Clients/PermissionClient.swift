import AppKit

protocol PermissionClient {
    func accessibilityStatus() -> PermissionStatus
    func requestAccessibility()
    func openAccessibilitySettings()
    func screenRecordingStatus() -> PermissionStatus
    func requestScreenRecording()
    func openScreenRecordingSettings()
}

struct SystemPermissionClient: PermissionClient {
    func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func screenRecordingStatus() -> PermissionStatus {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
