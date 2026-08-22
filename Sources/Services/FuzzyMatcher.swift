import Foundation

/// Minimal subsequence-based fuzzy matcher: "shw24" matches "0522 DEMO SHOW.show".
/// No dependency needed for the scale of a single MA3 folder tree.
enum FuzzyMatcher {
    /// Returns a score (higher = better match) or nil if `query`'s characters
    /// don't all appear, in order, within `text`.
    static func score(query: String, in text: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let queryChars = Array(query.lowercased())
        let textChars = Array(text.lowercased())
        var qi = 0
        var score = 0
        var lastMatchIndex = -1
        for (ti, char) in textChars.enumerated() {
            guard qi < queryChars.count else { break }
            if char == queryChars[qi] {
                score += (lastMatchIndex == ti - 1) ? 3 : 1
                lastMatchIndex = ti
                qi += 1
            }
        }
        guard qi == queryChars.count else { return nil }
        return score
    }
}
