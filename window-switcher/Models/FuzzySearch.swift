//
//  FuzzySearch.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-11.
//

// FuzzyCompare takes two strings and computes a similarity score between the two.
func FuzzyCompare(_ string1: String, _ string2: String) -> Int16 {
    let m = string1.lengthOfBytes(using: .utf8)
    let n = string2.lengthOfBytes(using: .utf8)
    
    var H = Array(repeating: Array(repeating: Int16(0), count: n + 1), count: m + 1)
    var highestScore = Int16(0)
    
    for (i, c1) in string1.enumerated() {
        // Shadow the index since the matrix requires the first column to be zeroed out.
        let i = i + 1
        for (j, c2) in string2.enumerated() {
            // Shadow the index since the matrix requires the first row to be zeroed out.
            let j = j + 1
                    
            // This is a simplification due to our choice of a linear gap penalty.
            H[i][j] = max(
                H[i - 1][j - 1] + (j == 1 && i == 1 ? 2 : 1) * score(c1, c2), // Add bias if first character is a match.
                H[i - 1][j] - 1 * gapPenaltyMultiplier,
                H[i][j - 1] - 1 * gapPenaltyMultiplier,
                0
            )
            
            highestScore = max(highestScore, H[i][j])
        }
    }
    
    // After filling in the matrix, get the max value.
    return highestScore
}

let gapPenaltyMultiplier = Int16(1)

// gapPenalty determines the penalty of having a gap in the string match in the smith-waterman algorithm.
func gapPenalty(_ distance: Int) -> Int {
    return distance
}

func score(_ c1: Character, _ c2: Character) -> Int16 {
    if c1 == c2 {
        return 3
    }
    
    return -3
}
