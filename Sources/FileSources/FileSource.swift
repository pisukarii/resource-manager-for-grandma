import Foundation

/// A path relative to a `FileSource`'s root, expressed as ordered components.
/// Kept independent of `URL`/absolute filesystem paths so the same taxonomy
/// can be resolved against very different backends (local disk, USB volume, SFTP).
struct RelativePath: Hashable, Sendable {
    var components: [String]

    static let root = RelativePath(components: [])

    init(components: [String] = []) {
        self.components = components
    }

    init(_ singleComponent: String) {
        self.components = [singleComponent]
    }

    func appending(_ component: String) -> RelativePath {
        RelativePath(components: components + [component])
    }

    func appending(_ other: RelativePath) -> RelativePath {
        RelativePath(components: components + other.components)
    }

    var displayPath: String {
        components.joined(separator: "/")
    }
}

struct FileEntry: Identifiable, Hashable, Sendable {
    var id: String { path.displayPath }
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?
    let path: RelativePath
}

enum SourceConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

enum FileSourceError: LocalizedError {
    case notConnected
    case pathNotFound(String)
    case revealNotSupported
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "接続されていません。"
        case .pathNotFound(let path):
            return "パスが見つかりません: \(path)"
        case .revealNotSupported:
            return "このSourceではFinder表示に対応していません。"
        case .underlying(let message):
            return message
        }
    }
}

/// Common interface every backend (local disk, USB volume, console over SFTP)
/// conforms to, so UI code never branches on backend kind.
@MainActor
protocol FileSource: AnyObject, Identifiable {
    var id: UUID { get }
    var config: SourceConfig { get }
    var connectionState: SourceConnectionState { get }

    func connect() async throws
    func list(_ path: RelativePath) async throws -> [FileEntry]
    /// `progress` reports fraction complete (0...1) when the backend can
    /// determine it (chunked SFTP transfer); nil is a valid/expected value
    /// for backends where progress isn't meaningful (fast local disk copy).
    func copyIn(from localURL: URL, to path: RelativePath, progress: (@Sendable (Double) -> Void)?) async throws
    func copyOut(from path: RelativePath, to localURL: URL, progress: (@Sendable (Double) -> Void)?) async throws
    func reveal(_ path: RelativePath) throws

    /// Whether this Source's display name can be edited from the sidebar.
    /// Always true today — kept as a protocol method (vs. mutating `config`
    /// directly) since `config` is otherwise read-only from outside the type.
    func updateName(_ newName: String)
    /// Prefix prepended before a category's uniform taxonomy path for this backend.
    func rootPrefix(for category: ConsoleCategory) -> RelativePath
    /// The real on-disk file URL backing this path, if any. Local/USB sources
    /// return it so file rows can be dragged straight to Finder/other apps
    /// without a round-trip through `copyOut`; network-backed sources (SFTP)
    /// return nil and rely on an explicit "Copy to Mac..." action instead.
    func localFileURL(for path: RelativePath) -> URL?

    /// Whether `rename`/`delete` are available on this backend. False by
    /// default (and for `ConsoleSFTPSource`): careless deletes on a real
    /// console's filesystem can leave it needing a reinstall, so destructive
    /// operations stay local/USB-only.
    var supportsDestructiveOperations: Bool { get }
    func rename(_ path: RelativePath, to newName: String) async throws
    func delete(_ path: RelativePath) async throws
}

extension FileSource {
    func categoryPath(for category: ConsoleCategory) -> RelativePath {
        rootPrefix(for: category).appending(category.relativePath)
    }

    func localFileURL(for path: RelativePath) -> URL? { nil }

    func copyIn(from localURL: URL, to path: RelativePath) async throws {
        try await copyIn(from: localURL, to: path, progress: nil)
    }

    func copyOut(from path: RelativePath, to localURL: URL) async throws {
        try await copyOut(from: path, to: localURL, progress: nil)
    }

    var supportsDestructiveOperations: Bool { false }

    func rename(_ path: RelativePath, to newName: String) async throws {
        throw FileSourceError.underlying("この Source ではリネームに対応していません。")
    }

    func delete(_ path: RelativePath) async throws {
        throw FileSourceError.underlying("この Source では削除に対応していません。")
    }
}
