import Foundation

actor ApplicationIndexStore {
    private let client: any InstalledApplicationsClient
    private var cachedApplications: [Application]?
    private var loadTask: Task<[Application], Never>?

    init(client: any InstalledApplicationsClient = SystemInstalledApplicationsClient()) {
        self.client = client
    }

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
            let client = self.client
            loadTask = Task.detached(priority: .utility) {
                client.installedApplications()
            }
        }

        let applications = await loadTask?.value ?? []
        cachedApplications = applications
        loadTask = nil
        return applications
    }
}
