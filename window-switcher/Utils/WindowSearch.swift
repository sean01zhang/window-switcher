import Foundation

enum WindowSearch {
    static func search(_ query: String, in windows: [Window]) -> [(Int16, Window)] {
        if query.isEmpty {
            return windows.map { (0, $0) }
        }

        var results: [(Int16, Window)] = []
        let includeCombinedScore = FuzzySearch.hasMultipleTerms(query)

        for window in windows {
            let titleMatch = FuzzySearch.match(query, against: window.name)
            let appMatch = FuzzySearch.match(query, against: window.appName)
            let combinedScore = includeCombinedScore
                ? FuzzySearch.match(query, against: window.fullyQualifiedName).score + 25
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

        results.sort { $0.0 > $1.0 }
        return results
    }
}
