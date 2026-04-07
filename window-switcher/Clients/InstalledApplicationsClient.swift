import AppKit

protocol InstalledApplicationsClient {
    func installedApplications() -> [Application]
}

struct SystemInstalledApplicationsClient: InstalledApplicationsClient {
    func installedApplications() -> [Application] {
        let fileManager = FileManager.default
        var applications: [Application] = []
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "\(NSHomeDirectory())/Applications"
        ]

        for path in searchPaths {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
                continue
            }

            for case let applicationURL as URL in enumerator where applicationURL.pathExtension == "app" {
                enumerator.skipDescendants()
                let bundle = Bundle(url: applicationURL)
                let name = bundle?.object(
                    forInfoDictionaryKey: "CFBundleName"
                ) as? String ?? applicationURL.deletingPathExtension().lastPathComponent
                applications.append(Application(name: name, url: applicationURL))
            }
        }

        return applications
    }
}
