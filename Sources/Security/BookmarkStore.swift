import Foundation

/// Defensive security-scoped bookmark handling. Not strictly required since
/// the app is non-sandboxed, but bookmarks survive volume remounts / path
/// changes better than raw path strings and keep the door open to future
/// sandboxing.
enum BookmarkStore {
    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Resolves a bookmark back to a URL, refreshing stale bookmarks in place.
    static func resolve(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        return url
    }
}
