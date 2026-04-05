import Foundation

struct FuzzySearch {
    struct Match: Equatable {
        let score: Int16
        let matched: Bool
        let isExactMatch: Bool
        let isPrefixMatch: Bool
        let isTokenPrefixMatch: Bool
        let matchedSpan: Int
        let matchedCount: Int
    }

    static func match(_ query: String, against candidate: String) -> Match {
        let normalizedQuery = normalize(query)
        let normalizedCandidate = normalize(candidate)

        guard !normalizedQuery.isEmpty, !normalizedCandidate.isEmpty else {
            return Match(
                score: 0,
                matched: false,
                isExactMatch: false,
                isPrefixMatch: false,
                isTokenPrefixMatch: false,
                matchedSpan: .max,
                matchedCount: 0
            )
        }

        let queryChars = Array(normalizedQuery)
        let candidateChars = Array(normalizedCandidate)

        var queryIndex = 0
        var score = 0
        var matchedIndices: [Int] = []
        var previousMatchIndex: Int?

        for candidateIndex in candidateChars.indices {
            guard queryIndex < queryChars.count else {
                break
            }

            if candidateChars[candidateIndex] != queryChars[queryIndex] {
                continue
            }

            matchedIndices.append(candidateIndex)
            score += 10

            if candidateIndex == 0 {
                score += 20
            } else {
                let previousCharacter = candidateChars[candidateIndex - 1]
                if isBoundaryCharacter(previousCharacter) {
                    score += 18
                }
            }

            if let previousMatchIndex {
                let gap = candidateIndex - previousMatchIndex - 1
                if gap == 0 {
                    score += 15
                } else {
                    score -= min(gap * 2, 12)
                }
            }

            previousMatchIndex = candidateIndex
            queryIndex += 1
        }

        guard queryIndex == queryChars.count, let firstIndex = matchedIndices.first, let lastIndex = matchedIndices.last else {
            return Match(
                score: 0,
                matched: false,
                isExactMatch: false,
                isPrefixMatch: false,
                isTokenPrefixMatch: false,
                matchedSpan: .max,
                matchedCount: 0
            )
        }

        let isExactMatch = normalizedQuery == normalizedCandidate
        let isPrefixMatch = normalizedCandidate.hasPrefix(normalizedQuery)
        let isTokenPrefixMatch = tokenPrefixRanges(in: candidateChars).contains { range in
            candidateSubstring(candidateChars, range).hasPrefix(normalizedQuery)
        }
        let matchedSpan = lastIndex - firstIndex + 1

        if isExactMatch {
            score += 80
        } else if isPrefixMatch {
            score += 45
        } else if isTokenPrefixMatch {
            score += 30
        } else if normalizedCandidate.contains(normalizedQuery) {
            score += 20
        }

        score -= min(max(matchedSpan - queryChars.count, 0), 20)
        score -= min(max(candidateChars.count - queryChars.count, 0) / 8, 6)

        return Match(
            score: Int16(max(score, 0)),
            matched: true,
            isExactMatch: isExactMatch,
            isPrefixMatch: isPrefixMatch,
            isTokenPrefixMatch: isTokenPrefixMatch,
            matchedSpan: matchedSpan,
            matchedCount: matchedIndices.count
        )
    }

    static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hasMultipleTerms(_ string: String) -> Bool {
        normalize(string).contains(where: isBoundaryCharacter)
    }

    private static func isBoundaryCharacter(_ character: Character) -> Bool {
        character == " " || character == ":" || character == "/" || character == "-" || character == "_"
    }

    private static func tokenPrefixRanges(in characters: [Character]) -> [Range<Int>] {
        guard !characters.isEmpty else {
            return []
        }

        var ranges: [Range<Int>] = []
        var tokenStart = 0

        for index in characters.indices {
            if isBoundaryCharacter(characters[index]) {
                if tokenStart < index {
                    ranges.append(tokenStart..<index)
                }
                tokenStart = index + 1
            }
        }

        if tokenStart < characters.count {
            ranges.append(tokenStart..<characters.count)
        }

        return ranges
    }

    private static func candidateSubstring(_ characters: [Character], _ range: Range<Int>) -> String {
        String(characters[range])
    }
}

func FuzzyCompare(_ string1: String, _ string2: String) -> Int16 {
    FuzzySearch.match(string1, against: string2).score
}
