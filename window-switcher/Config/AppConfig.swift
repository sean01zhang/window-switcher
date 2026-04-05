import Foundation

struct AppConfig: Equatable {
    var trigger: TriggerShortcut
    var navigation: NavigationConfig
    var resultListItem: ResultListItemConfig

    static let `default` = AppConfig(
        trigger: .default,
        navigation: .default,
        resultListItem: .default
    )
}

struct RawAppConfig: Decodable {
    var trigger: RawShortcutConfig?
    var navigation: RawNavigationConfig?
    var resultListItem: RawResultListItemConfig?

    enum CodingKeys: String, CodingKey {
        case trigger
        case navigation
        case resultListItem = "result"
    }
}

struct RawShortcutConfig: Decodable {
    var key: String?
    var modifiers: [String]?
}

struct NavigationConfig: Equatable {
    var next: [TriggerShortcut]
    var previous: [TriggerShortcut]

    static let `default` = NavigationConfig(
        next: [
            TriggerShortcut(key: .j, modifiers: [.control]),
            TriggerShortcut(key: .n, modifiers: [.control])
        ],
        previous: [
            TriggerShortcut(key: .k, modifiers: [.control]),
            TriggerShortcut(key: .p, modifiers: [.control])
        ]
    )
}

struct RawNavigationConfig: Decodable {
    var next: RawShortcutListConfig?
    var previous: RawShortcutListConfig?
}

struct RawShortcutListConfig: Decodable {
    let shortcuts: [RawShortcutConfig]

    init(from decoder: Decoder) throws {
        if let list = try? [RawShortcutConfig](from: decoder) {
            self.shortcuts = list
            return
        }

        let single = try RawShortcutConfig(from: decoder)
        self.shortcuts = [single]
    }
}

struct ResultListItemConfig: Equatable {
    var window: ResultListItemTemplate
    var app: ResultListItemTemplate

    static let `default` = ResultListItemConfig(
        window: ResultListItemTemplate(template: "{app_name}: {title}"),
        app: ResultListItemTemplate(template: "Open {name}")
    )
}

struct ResultListItemTemplate: Equatable {
    var template: String
}

struct RawResultListItemConfig: Decodable {
    var window: RawResultListItemFormat?
    var app: RawResultListItemFormat?
}

struct RawResultListItemFormat: Decodable {
    var template: String?
}
