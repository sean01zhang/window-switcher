//
//  AccessibilityClient.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-11-03.
//
import AppKit

class A11yClient {
    static func ensurePrompt() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
