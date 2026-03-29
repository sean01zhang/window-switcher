import Foundation
import Observation

@MainActor
@Observable
final class ConfigStore {
    static let shared = ConfigStore()

    private(set) var config: AppConfig = .default

    private init() {}

    func reload() {
        config = ConfigLoader.load()
    }

    func reloadIfNeededForOpen() {
        reload()
    }
}
