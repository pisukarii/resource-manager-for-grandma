import AppKit
import Foundation

/// Finds a GDTF for a grandMA2 `.pxml` fixture on GDTF Share (gdtf-share.com).
///
/// Opens the site's own search page with the words filled in:
/// `share.php?page=home&query=<words>&man=1&fix=1&rev=1&use=0` (man/fix/rev
/// = search manufacturer, fixture and revision names). GDTF Share needs a
/// login, so in a browser that isn't signed in it lands on the login page
/// first — the words are also put on the clipboard for that case.
enum GDTFShareSearch {
    enum Scope {
        /// Model only (e.g. "p-5w"): the most specific, and the site's search
        /// matches each field separately, so "sgm p-5w" together would find nothing.
        case model
        /// Manufacturer only (e.g. "sgm").
        case manufacturer
    }

    /// "sgm@p-5w.pxml" -> ("sgm", "p-5w"). Without an "@", the whole name is the model.
    static func parts(fromFileName fileName: String) -> (manufacturer: String, model: String) {
        let stem = (fileName as NSString).deletingPathExtension
        let pieces = stem.components(separatedBy: "@")
        let clean: (String) -> String = { $0.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces) }
        if pieces.count >= 2 { return (clean(pieces[0]), clean(pieces[1])) }
        return ("", clean(stem))
    }

    static func searchWords(forFileName fileName: String, scope: Scope = .model) -> String {
        let p = parts(fromFileName: fileName)
        switch scope {
        case .model: return p.model.isEmpty ? p.manufacturer : p.model
        case .manufacturer: return p.manufacturer.isEmpty ? p.model : p.manufacturer
        }
    }

    static func searchURL(for words: String) -> URL? {
        var components = URLComponents(string: "https://gdtf-share.com/share.php")
        components?.queryItems = [
            URLQueryItem(name: "page", value: "home"),
            URLQueryItem(name: "query", value: words),
            URLQueryItem(name: "man", value: "1"),
            URLQueryItem(name: "fix", value: "1"),
            URLQueryItem(name: "rev", value: "1"),
            URLQueryItem(name: "use", value: "0"),
        ]
        return components?.url
    }

    /// Opens the search in the default browser (and copies the words).
    @MainActor
    @discardableResult
    static func open(fileName: String, scope: Scope = .model) -> String {
        let words = searchWords(forFileName: fileName, scope: scope)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(words, forType: .string)
        if let url = searchURL(for: words) { NSWorkspace.shared.open(url) }
        return words
    }
}
