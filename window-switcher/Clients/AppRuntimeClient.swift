import AppKit

struct AppRuntimeClient {
    var versionIdentifier: () -> String
    var terminate: () -> Void
    var relaunch: () throws -> Void

    static let live = AppRuntimeClient(
        versionIdentifier: {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        },
        terminate: {
            NSApplication.shared.terminate(nil)
        },
        relaunch: {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", Bundle.main.bundleURL.path]
            try task.run()
            NSApp.terminate(nil)
        }
    )
}
