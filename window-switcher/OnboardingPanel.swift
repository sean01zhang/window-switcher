import AppKit
import SwiftUI

final class OnboardingPanel: NSWindow {
    private let permissionStore: PermissionStore
    private let onAccessibilityGranted: () -> Void
    let onClose: () -> Void

    init(
        permissionStore: PermissionStore,
        onAccessibilityGranted: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.permissionStore = permissionStore
        self.onAccessibilityGranted = onAccessibilityGranted
        self.onClose = onClose

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )

        contentView = NSHostingView(
            rootView: OnboardingView(
                permissionStore: permissionStore,
                onDismiss: { [weak self] in self?.close() }
            )
        )
        title = "Welcome to Window Switcher"
        center()
        isReleasedWhenClosed = false
    }

    override func becomeKey() {
        super.becomeKey()
        refreshPermissionsAndNotifyIfNeeded()
    }

    override func close() {
        super.close()
        onClose()
    }

    private func refreshPermissionsAndNotifyIfNeeded() {
        permissionStore.refreshAll()
        if permissionStore.requiredPermissionsGranted {
            onAccessibilityGranted()
        }
    }
}
