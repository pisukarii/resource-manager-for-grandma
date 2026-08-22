using GrandMAResourceManager.Models;
using GrandMAResourceManager.Sources;

namespace GrandMAResourceManager.Services;

public sealed record IndexedEntry(SourceConfig Source, string SourceName, ConsoleCategory Category, FileEntry Entry);

/// <summary>
/// Background-built cache of filenames across every configured Source's
/// taxonomy category roots, powering the Quick Open window. Depth is capped
/// to each category's direct contents (not recursive) to keep refreshes
/// fast. Ported from the macOS app's FileIndex.swift.
/// </summary>
public sealed class FileIndex
{
    private List<IndexedEntry> _entries = new();

    public async Task RefreshAsync(IEnumerable<IFileSource> sources)
    {
        var collected = new List<IndexedEntry>();
        foreach (var source in sources)
        {
            foreach (var category in source.Config.ResolvedFamily.Categories())
            {
                List<FileEntry> items;
                try
                {
                    items = await source.ListAsync(source.CategoryPath(category));
                }
                catch
                {
                    continue;
                }
                foreach (var item in items)
                {
                    collected.Add(new IndexedEntry(source.Config, source.Config.Name, category, item));
                }
            }
        }
        _entries = collected;
    }

    public List<IndexedEntry> Search(string query)
    {
        if (string.IsNullOrEmpty(query)) return new List<IndexedEntry>();
        return _entries
            .Select(indexed => (indexed, score: FuzzyMatcher.Score(query, indexed.Entry.Name)))
            .Where(x => x.score is not null)
            .OrderByDescending(x => x.score)
            .Take(50)
            .Select(x => x.indexed)
            .ToList();
    }
}
