import AppKit

struct Application: Hashable {
    let name: String
    let url: URL
}

actor ApplicationIndex {
    static let shared = ApplicationIndex()

    private var cachedApplications: [Application]?
    private var loadTask: Task<[Application], Never>?

    func preload() async {
        _ = await applications()
    }

    func applications() async -> [Application] {
        if let cachedApplications {
            return cachedApplications
        }

        if loadTask == nil {
            loadTask = Task.detached(priority: .utility) {
                loadInstalledApplications()
            }
        }

        let applications = await loadTask?.value ?? []
        cachedApplications = applications
        loadTask = nil
        return applications
    }

    func search(_ query: String) async -> [(Int16, Application)] {
        guard !query.isEmpty else {
            return []
        }

        return await applications().compactMap { app in
            let score = FuzzySearch.match(query, against: app.name).score
            guard score > 0 else {
                return nil
            }

            return (score, app)
        }
    }
}

private func loadInstalledApplications() -> [Application] {
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
