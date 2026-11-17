import Observation

@MainActor
@Observable
final class AppUIState {
    var isQuickOpenPresented = false
    /// Driven from the menu bar ("Sourceを追加...") as well as the sidebar.
    var isAddSourcePresented = false
    /// Bumped by the menu bar's "一覧を更新"; the file list reloads on change.
    var refreshTick = 0
    /// Set when a GDTF Share search is started: shows the "where it goes +
    /// drop the download here" sheet.
    var gdtfDrop: GDTFDropRequest?

    /// Opens the GDTF Share search for a grandMA2 `.pxml` and shows the drop sheet.
    func searchGDTFShare(fileName: String, scope: GDTFShareSearch.Scope) {
        let words = GDTFShareSearch.open(fileName: fileName, scope: scope)
        gdtfDrop = GDTFDropRequest(fileName: fileName, words: words)
    }
}
