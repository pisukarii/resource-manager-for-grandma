namespace GrandMAResourceManager.Services;

/// <summary>
/// Minimal subsequence-based fuzzy matcher: "shw24" matches
/// "0522 DEMO SHOW.show". Ported from the macOS app's FuzzyMatcher.swift.
/// </summary>
public static class FuzzyMatcher
{
    /// <summary>Returns a score (higher = better) or null if query's characters
    /// don't all appear, in order, within text.</summary>
    public static int? Score(string query, string text)
    {
        if (query.Length == 0) return 0;
        var q = query.ToLowerInvariant();
        var t = text.ToLowerInvariant();

        var qi = 0;
        var score = 0;
        var lastMatchIndex = -1;
        for (var ti = 0; ti < t.Length; ti++)
        {
            if (qi >= q.Length) break;
            if (t[ti] == q[qi])
            {
                score += lastMatchIndex == ti - 1 ? 3 : 1;
                lastMatchIndex = ti;
                qi++;
            }
        }
        return qi == q.Length ? score : null;
    }
}
