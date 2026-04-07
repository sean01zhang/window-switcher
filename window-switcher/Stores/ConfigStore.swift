import Foundation
import Observation

@MainActor
@Observable
final class ConfigStore {
    private(set) var config: AppConfig = .default

    func reload() {
        config = ConfigLoader.load()
    }
}
