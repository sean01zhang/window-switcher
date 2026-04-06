import AppKit
import SwiftUI

class OnboardingWindow: NSWindow, NSWindowDelegate {
    private let onDismissCallback: () -> Void

    init(permissionManager: PermissionManager, onDismiss: @escaping () -> Void) {
        self.onDismissCallback = onDismiss
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )

        delegate = self

        let onboardingView = OnboardingView(
            permissionManager: permissionManager,
            onDismiss: { [weak self] in self?.close() },
            onRelaunch: relaunchApplication
        )
        contentView = NSHostingView(rootView: onboardingView)

        title = "Welcome to Window Switcher"
        center()
        isReleasedWhenClosed = false
    }

    func windowWillClose(_ notification: Notification) {
        onDismissCallback()
    }

    private func relaunchApplication() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unable to Relaunch"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
