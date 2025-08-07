import AppKit

struct Application: Hashable {
    let name: String
    let url: URL
}

func getInstalledApplications() -> [Application] {
    let fileManager = FileManager.default
    var apps: [Application] = []
    let searchPaths = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]
    for path in searchPaths {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let appURL as URL in enumerator {
                if appURL.pathExtension == "app" {
                    enumerator.skipDescendants()
                    let bundle = Bundle(url: appURL)
                    let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? appURL.deletingPathExtension().lastPathComponent
                    apps.append(Application(name: name, url: appURL))
                }
            }
        }
    }
    return apps
}

