import AppKit

enum AccessibilityPermissions {
    static func ensurePrompt() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let options: [CFString: Any] = [kAXTrustedCheckOptionPrompt: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
