import Foundation

enum WindowResultListItemProperty: String, CaseIterable {
    case appName = "app_name"
    case title
    case name
    case fullyQualifiedName = "fqn"
    case id
    case appPID = "app_pid"
    case x
    case y
    case width
    case height
}

enum ApplicationResultListItemProperty: String, CaseIterable {
    case name
    case path
}

extension String {
    func substituting(_ values: [String: any CustomStringConvertible]) -> String {
        let pattern = #"\{([A-Za-z0-9_]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        let source = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else {
            return self
        }

        var result = ""
        var currentLocation = 0

        for match in matches {
            let matchRange = match.range(at: 0)
            let keyRange = match.range(at: 1)

            if matchRange.location > currentLocation {
                result += source.substring(with: NSRange(
                    location: currentLocation,
                    length: matchRange.location - currentLocation
                ))
            }

            let key = source.substring(with: keyRange)
            if let value = values[key] {
                result += String(describing: value)
            } else {
                result += source.substring(with: matchRange)
            }

            currentLocation = matchRange.location + matchRange.length
        }

        if currentLocation < source.length {
            result += source.substring(from: currentLocation)
        }

        return result
    }
}

enum ResultListItemFormatter {
    static func text(for item: SearchItem, config: ResultListItemConfig) -> String {
        switch item {
        case .window(let window):
            return config.window.template.substituting(windowTemplateValues(window))
        case .application(let application):
            return config.app.template.substituting(applicationTemplateValues(application))
        }
    }
}

private func windowTemplateValues(_ window: Window) -> [String: any CustomStringConvertible] {
    [
        WindowResultListItemProperty.appName.rawValue: window.appName,
        WindowResultListItemProperty.title.rawValue: window.name,
        WindowResultListItemProperty.name.rawValue: window.name,
        WindowResultListItemProperty.fullyQualifiedName.rawValue: window.fullyQualifiedName,
        WindowResultListItemProperty.id.rawValue: window.id,
        WindowResultListItemProperty.appPID.rawValue: window.appPID,
        WindowResultListItemProperty.x.rawValue: Double(window.frame?.origin.x ?? 0),
        WindowResultListItemProperty.y.rawValue: Double(window.frame?.origin.y ?? 0),
        WindowResultListItemProperty.width.rawValue: Double(window.frame?.size.width ?? 0),
        WindowResultListItemProperty.height.rawValue: Double(window.frame?.size.height ?? 0)
    ]
}

private func applicationTemplateValues(_ application: Application) -> [String: any CustomStringConvertible] {
    [
        ApplicationResultListItemProperty.name.rawValue: application.name,
        ApplicationResultListItemProperty.path.rawValue: application.url.path
    ]
}
