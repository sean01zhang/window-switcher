import Foundation

struct AppConfig: Equatable {
    var trigger: TriggerShortcut

    static let `default` = AppConfig(trigger: .default)
}

struct RawAppConfig: Decodable {
    var trigger: RawTriggerConfig?
}

struct RawTriggerConfig: Decodable {
    var key: String?
    var modifiers: [String]?
}
