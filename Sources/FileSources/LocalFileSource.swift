import Foundation
import AppKit
import Observation

/// Backs a source that lives entirely on local disk: either an onPC install
/// (rooted at `~/MALightingTechnology`, with `shows`/`backups` scoped to a
/// chosen `gma3_x.y.z` version folder and `gma3_library` shared across all
/// versions) or a mounted USB volume (rooted at `<volume>/grandMA3`, uniform
/// for every category — no per-version split). Both are just `FileManager`
/// access with no network involved, so one class backs both; the difference
/// is entirely in how `rootPrefix(for:)` is resolved, supplied at init.
@MainActor
@Observable
final class DiskFileSource: FileSource {
    let id: UUID
    private(set) var config: SourceConfig
    private(set) var connectionState: SourceConnectionState = .disconnected

    private let rootURL: URL
    private let prefixResolver: (ConsoleCategory) -> RelativePath

    init(config: SourceConfig, rootURL: URL, prefixResolver: @escaping (ConsoleCategory) -> RelativePath) {
        self.id = config.id
        self.config = config
        self.rootURL = rootURL
        self.prefixResolver = prefixResolver
    }

    func connect() async throws {
        let url = rootURL
        let exists = await Task.detached(priority: .userInitiated) {
            FileManager.default.fileExists(atPath: url.path)
        }.value
        connectionState = exists ? .connected : .error("フォルダが見つかりません: \(url.path)")
        if !exists {
            throw FileSourceError.pathNotFound(url.path)
        }
    }

    func rootPrefix(for category: ConsoleCategory) -> RelativePath {
        prefixResolver(category)
    }

    func list(_ path: RelativePath) async throws -> [FileEntry] {
        let targetURL = url(for: path)
        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let contents = try fm.contentsOfDirectory(
                at: targetURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            return contents.map { itemURL -> FileEntry in
                let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                return FileEntry(
                    name: itemURL.lastPathComponent,
                    isDirectory: values?.isDirectory ?? false,
                    size: values?.fileSize.map { Int64($0) },
                    modifiedDate: values?.contentModificationDate,
                    path: path.appending(itemURL.lastPathComponent)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }.value
    }

    func copyIn(from localURL: URL, to path: RelativePath, progress: (@Sendable (Double) -> Void)?) async throws {
        let destinationURL = url(for: path).appendingPathComponent(localURL.lastPathComponent)
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.copyItem(at: localURL, to: destinationURL)
        }.value
        // Local disk copies are fast enough that streaming progress isn't
        // worth the complexity (directories in particular); report done.
        progress?(1.0)
    }

    func copyOut(from path: RelativePath, to localURL: URL, progress: (@Sendable (Double) -> Void)?) async throws {
        let sourceURL = url(for: path)
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            if fm.fileExists(atPath: localURL.path) {
                try fm.removeItem(at: localURL)
            }
            try fm.copyItem(at: sourceURL, to: localURL)
        }.value
        progress?(1.0)
    }

    func reveal(_ path: RelativePath) throws {
        NSWorkspace.shared.activateFileViewerSelecting([url(for: path)])
    }

    func localFileURL(for path: RelativePath) -> URL? {
        url(for: path)
    }

    func updateName(_ newName: String) {
        config.name = newName
    }

    var supportsDestructiveOperations: Bool { true }

    func rename(_ path: RelativePath, to newName: String) async throws {
        let sourceURL = url(for: path)
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        }.value
    }

    /// Moves to Trash rather than permanently deleting, so a confirmed
    /// delete is still recoverable via Finder if it was a mistake.
    func delete(_ path: RelativePath) async throws {
        let targetURL = url(for: path)
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.trashItem(at: targetURL, resultingItemURL: nil)
        }.value
    }

    private func url(for path: RelativePath) -> URL {
        path.components.reduce(rootURL) { $0.appendingPathComponent($1) }
    }
}
