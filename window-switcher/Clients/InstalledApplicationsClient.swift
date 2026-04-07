import AppKit

actor InstalledApplicationsClient {
    private var cachedApplications: [Application]?
    private var loadTask: Task<[Application], Never>?

    func preload() async {
        _ = await applications()
    }

    func search(_ query: String) async -> [(Int16, Application)] {
        guard !query.isEmpty else {
            return []
        }

        return await applications().compactMap { application in
            let score = FuzzySearch.match(query, against: application.name).score
            guard score > 0 else {
                return nil
            }

            return (score, application)
        }
    }

    private func applications() async -> [Application] {
        if let cachedApplications {
            return cachedApplications
        }

        if loadTask == nil {
            loadTask = Task.detached(priority: .utility) {
                Self.loadInstalledApplications()
            }
        }

        let applications = await loadTask?.value ?? []
        cachedApplications = applications
        loadTask = nil
        return applications
    }

    private static func loadInstalledApplications() -> [Application] {
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
