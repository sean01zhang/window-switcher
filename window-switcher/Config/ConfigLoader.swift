import Foundation
import TOMLDecoder

enum ConfigFileError: LocalizedError {
    case configPathIsDirectory(URL)

    var errorDescription: String? {
        switch self {
        case .configPathIsDirectory(let fileURL):
            return "Expected a config file at \(fileURL.path), but found a directory instead."
        }
    }
}

struct ConfigLoader {
    static let defaultConfigDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config", isDirectory: true)
        .appendingPathComponent("window-switcher", isDirectory: true)

    static let defaultConfigURL = defaultConfigDirectoryURL
        .appendingPathComponent("config.toml", isDirectory: false)

    static let defaultConfigContents = """
    [trigger]
    key = "tab"
    modifiers = ["option"]

    [navigation]
    next = [
      { key = "j", modifiers = ["control"] },
      { key = "n", modifiers = ["control"] }
    ]
    previous = [
      { key = "k", modifiers = ["control"] },
      { key = "p", modifiers = ["control"] }
    ]

    [result.window]
    template = "{app_name}: {title}"

    [result.app]
    template = "Open {name}"
    """

    static func load(from fileURL: URL = defaultConfigURL) -> AppConfig {
        do {
            let data = try Data(contentsOf: fileURL)
            return load(from: data)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                return .default
            }

            print("warning: failed to read config at \(fileURL.path): \(error.localizedDescription)")
            return .default
        }
    }

    static func load(from data: Data) -> AppConfig {
        do {
            let rawConfig = try TOMLDecoder().decode(RawAppConfig.self, from: data)
            return resolve(rawConfig)
        } catch {
            print("warning: failed to decode window switcher config: \(error.localizedDescription)")
            return .default
        }
    }

    static func resolve(_ rawConfig: RawAppConfig) -> AppConfig {
        var config = AppConfig.default

        if let rawTrigger = rawConfig.trigger {
            if let trigger = TriggerShortcut(raw: rawTrigger) {
                config.trigger = trigger
            } else {
                print("warning: invalid trigger config, falling back to default")
            }
        }

        if let rawNavigation = rawConfig.navigation {
            if let rawNext = rawNavigation.next {
                if let next = resolveShortcutList(rawNext.shortcuts, warningLabel: "navigation.next") {
                    config.navigation.next = next
                } else {
                    print("warning: invalid navigation.next config, falling back to default")
                }
            }

            if let rawPrevious = rawNavigation.previous {
                if let previous = resolveShortcutList(rawPrevious.shortcuts, warningLabel: "navigation.previous") {
                    config.navigation.previous = previous
                } else {
                    print("warning: invalid navigation.previous config, falling back to default")
                }
            }
        }

        if let rawResultListItem = rawConfig.resultListItem {
            if let rawWindow = rawResultListItem.window {
                config.resultListItem.window = resolveResultListItemTemplate(
                    rawWindow,
                    defaultConfig: config.resultListItem.window,
                    warningLabel: "result.window"
                )
            }

            if let rawApp = rawResultListItem.app {
                config.resultListItem.app = resolveResultListItemTemplate(
                    rawApp,
                    defaultConfig: config.resultListItem.app,
                    warningLabel: "result.app"
                )
            }
        }

        return config
    }

    private static func resolveShortcutList(
        _ rawShortcuts: [RawShortcutConfig],
        warningLabel: String
    ) -> [TriggerShortcut]? {
        guard !rawShortcuts.isEmpty else {
            print("warning: \(warningLabel) config must include at least one shortcut")
            return nil
        }

        var shortcuts: [TriggerShortcut] = []
        for rawShortcut in rawShortcuts {
            guard let shortcut = TriggerShortcut(raw: rawShortcut) else {
                return nil
            }
            shortcuts.append(shortcut)
        }

        return shortcuts
    }

    private static func resolveResultListItemTemplate(
        _ rawConfig: RawResultListItemFormat,
        defaultConfig: ResultListItemTemplate,
        warningLabel: String
    ) -> ResultListItemTemplate {
        var resolved = defaultConfig

        if let template = rawConfig.template {
            if template.isEmpty {
                print("warning: \(warningLabel).template must not be empty")
            } else {
                resolved.template = template
            }
        }

        return resolved
    }

    @discardableResult
    static func ensureConfigFileExists(at fileURL: URL = defaultConfigURL) throws -> URL {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        var isDirectory = ObjCBool(false)
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)

        if fileExists && isDirectory.boolValue {
            throw ConfigFileError.configPathIsDirectory(fileURL)
        }

        if !fileExists {
            try defaultConfigContents.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return fileURL
    }
}
