import AppKit

struct Window: Hashable {
    var id: Int
    var appName: String
    var appPID: Int32
    var name: String
    var frame: CGRect?
    var element: AXUIElement

    func hash(into hasher: inout Hasher) {
        element.hash(into: &hasher)
    }

    static func == (lhs: Window, rhs: Window) -> Bool {
        lhs.element == rhs.element
    }

    func fqn() -> String {
        "\(appName): \(name)"
    }
}

final class Windows {
    static func search(_ query: String, _ windows: [Window]) -> [(Int16, Window)] {
       if query.isEmpty {
           return windows.map({ (0, $0) })
       }

       var results: [(Int16, Window)] = []
       let includeCombinedScore = FuzzySearch.hasMultipleTerms(query)

       for window in windows {
           let titleMatch = FuzzySearch.match(query, against: window.name)
           let appMatch = FuzzySearch.match(query, against: window.appName)
           let combinedScore = includeCombinedScore
               ? FuzzySearch.match(query, against: window.fqn()).score + 25
               : 0
           let score = max(
               titleMatch.score + 80,
               appMatch.score + 15,
               combinedScore
           )

           if score > 0 {
               results.append((score, window))
           }
       }

       results.sort(by: { $0.0 > $1.0 })
       return results
   }
}
