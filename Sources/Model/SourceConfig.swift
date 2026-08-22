import Foundation

enum SourceKind: String, Codable, CaseIterable {
    case local
    case usb
    case sftp

    var displayName: String {
        switch self {
        case .local: return "ローカル (onPC)"
        case .usb: return "USBメモリ"
        case .sftp: return "コンソール (SFTP)"
        }
    }

    var symbolName: String {
        switch self {
        case .local: return "laptopcomputer"
        case .usb: return "externaldrive"
        case .sftp: return "network"
        }
    }
}

/// A user-configured connection to one of the three grandMA3 file locations.
/// Persisted as JSON by `SourceStore`.
struct SourceConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var kind: SourceKind

    // .local: path to the chosen gma3_x.y.z version folder.
    // .usb: path to the console's data-root folder on the volume,
    //   e.g. /Volumes/STICK/grandMA3 or /Volumes/STICK/gma2 (see `family`).
    var path: String?
    var bookmarkData: Data?

    // .sftp
    var host: String?
    var port: Int?
    var username: String?
    /// Override for the console-side root path, since it could not be
    /// confirmed ahead of testing against a real console.
    var basePathOverride: String?

    /// Which console generation's folder layout this Source uses. Only ever
    /// varies for `.usb` (grandMA3 vs grandMA2 sticks); `.local` and `.sftp`
    /// are always `.ma3`. Optional so existing saved configs without this
    /// field (from before MA2 support) decode as `.ma3` via `resolvedFamily`.
    var family: ConsoleFamily?

    var resolvedFamily: ConsoleFamily { family ?? .ma3 }

    init(
        id: UUID = UUID(),
        name: String,
        kind: SourceKind,
        path: String? = nil,
        bookmarkData: Data? = nil,
        host: String? = nil,
        port: Int? = 22,
        username: String? = nil,
        basePathOverride: String? = nil,
        family: ConsoleFamily? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.path = path
        self.bookmarkData = bookmarkData
        self.host = host
        self.port = port
        self.username = username
        self.basePathOverride = basePathOverride
        self.family = family
    }
}
