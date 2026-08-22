import Foundation
import Observation

struct IndexedEntry: Identifiable, Hashable {
    var id: String { "\(sourceID)/\(entry.path.displayPath)" }
    let sourceID: UUID
    let sourceName: String
    let category: ConsoleCategory
    let entry: FileEntry
}

/// Background-built cache of filenames across every configured Source's
/// taxonomy category roots, powering `QuickOpenPalette`'s fuzzy search.
/// Depth is capped to each category's direct contents (not recursive) to
/// keep refreshes fast; the palette exposes a manual refresh action.
@MainActor
@Observable
final class FileIndex {
    private(set) var entries: [IndexedEntry] = []
    private(set) var isRefreshing = false
    private(set) var lastRefreshed: Date?

    func refresh(sources: [any FileSource]) async {
        isRefreshing = true
        defer { isRefreshing = false }

        var collected: [IndexedEntry] = []
        for source in sources {
            for category in source.config.resolvedFamily.categories {
                let path = source.categoryPath(for: category)
                guard let items = try? await source.list(path) else { continue }
                for item in items {
                    collected.append(IndexedEntry(
                        sourceID: source.id,
                        sourceName: source.config.name,
                        category: category,
                        entry: item
                    ))
                }
            }
        }
        entries = collected
        lastRefreshed = Date()
    }

    func search(_ query: String) -> [IndexedEntry] {
        guard !query.isEmpty else { return [] }
        return entries
            .compactMap { indexed -> (IndexedEntry, Int)? in
                guard let score = FuzzyMatcher.score(query: query, in: indexed.entry.name) else { return nil }
                return (indexed, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(50)
            .map { $0.0 }
    }
}
