import AppKit

protocol WorkspaceClient {
    func openURL(_ url: URL) -> Bool
    func openApplication(_ url: URL)
    func iconForFile(_ path: String) -> NSImage
    func runningApplicationIcon(processIdentifier: Int32) -> NSImage?
}

struct SystemWorkspaceClient: WorkspaceClient {
    func openURL(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    func openApplication(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration,
            completionHandler: nil
        )
    }

    func iconForFile(_ path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    func runningApplicationIcon(processIdentifier: Int32) -> NSImage? {
        NSRunningApplication(processIdentifier: processIdentifier)?.icon
    }
}
