import Foundation

struct AppConfig: Equatable {
    var trigger: TriggerShortcut
    var quickSwitch: QuickSwitchConfig
    var navigation: NavigationConfig
    var resultListItem: ResultListItemConfig

    static let `default` = AppConfig(
        trigger: .default,
        quickSwitch: .default,
        navigation: .default,
        resultListItem: .default
    )
}

struct RawAppConfig: Decodable {
    var trigger: RawShortcutConfig?
    var quickSwitch: RawQuickSwitchConfig?
    var navigation: RawNavigationConfig?
    var resultListItem: RawResultListItemConfig?

    enum CodingKeys: String, CodingKey {
        case trigger
        case quickSwitch = "quick_switch"
        case navigation
        case resultListItem = "result"
    }
}

struct RawShortcutConfig: Decodable {
    var key: String?
    var modifiers: [String]?
}

struct QuickSwitchConfig: Equatable {
    var enabled: Bool

    static let `default` = QuickSwitchConfig(enabled: false)
}

struct RawQuickSwitchConfig: Decodable {
    var enabled: Bool?
}

struct NavigationConfig: Equatable {
    var next: [TriggerShortcut]
    var previous: [TriggerShortcut]
    var enterSelection: [TriggerShortcut]

    static let `default` = NavigationConfig(
        next: [
            TriggerShortcut(key: .j, modifiers: [.control]),
            TriggerShortcut(key: .n, modifiers: [.control])
        ],
        previous: [
            TriggerShortcut(key: .k, modifiers: [.control]),
            TriggerShortcut(key: .p, modifiers: [.control])
        ],
        enterSelection: [
            TriggerShortcut(key: .y, modifiers: [.control])
        ]
    )
}

struct RawNavigationConfig: Decodable {
    var next: RawShortcutListConfig?
    var previous: RawShortcutListConfig?
    var enterSelection: RawShortcutListConfig?

    enum CodingKeys: String, CodingKey {
        case next
        case previous
        case enterSelection = "enter_selection"
    }
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
