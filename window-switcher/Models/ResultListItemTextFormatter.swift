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

enum ResultListItemTextFormatter {
    static func text(for item: SearchItem, config: ResultListItemConfig) -> String {
        switch item {
        case .window(let window):
            return config.window.template.substituting(window.templateValues)
        case .application(let app):
            return config.app.template.substituting(app.templateValues)
        }
    }
}

private extension Window {
    var templateValues: [String: any CustomStringConvertible] {
        [
            WindowResultListItemProperty.appName.rawValue: appName,
            WindowResultListItemProperty.title.rawValue: name,
            WindowResultListItemProperty.name.rawValue: name,
            WindowResultListItemProperty.fullyQualifiedName.rawValue: fqn(),
            WindowResultListItemProperty.id.rawValue: id,
            WindowResultListItemProperty.appPID.rawValue: appPID,
            WindowResultListItemProperty.x.rawValue: Double(frame?.origin.x ?? 0),
            WindowResultListItemProperty.y.rawValue: Double(frame?.origin.y ?? 0),
            WindowResultListItemProperty.width.rawValue: Double(frame?.size.width ?? 0),
            WindowResultListItemProperty.height.rawValue: Double(frame?.size.height ?? 0)
        ]
    }
}

private extension Application {
    var templateValues: [String: any CustomStringConvertible] {
        [
            ApplicationResultListItemProperty.name.rawValue: name,
            ApplicationResultListItemProperty.path.rawValue: url.path
        ]
    }
}
