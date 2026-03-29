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
        guard let rawTrigger = rawConfig.trigger else {
            return .default
        }

        guard let trigger = TriggerShortcut(raw: rawTrigger) else {
            print("warning: invalid trigger config, falling back to default")
            return .default
        }

        return AppConfig(trigger: trigger)
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
