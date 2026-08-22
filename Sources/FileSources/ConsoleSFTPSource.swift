import Foundation
import Citadel
import NIO
import Observation

/// Backs a source that connects to a real grandMA3 console over SFTP (port
/// 22, via the console's Manet network adapter).
///
/// The console-side base path is `/MALighting/grandma3` (confirmed
/// 2026-08-19, Linux console filesystem — same relative layout under it as
/// `MA3FolderTaxonomy` describes for onPC/USB). `SFTPConnectionForm`
/// pre-fills this as the default; `config.basePathOverride` still exists so
/// it can be corrected per-console (different model/version) without a
/// code change.
///
/// v1 deliberately implements copy-in / copy-out / list / reveal only — no
/// delete, rename, or move — since careless file operations on a console's
/// filesystem can leave it needing a reinstall.
@MainActor
@Observable
final class ConsoleSFTPSource: FileSource {
    let id: UUID
    private(set) var config: SourceConfig
    private(set) var connectionState: SourceConnectionState = .disconnected

    private var sshClient: SSHClient?
    private var sftpClient: SFTPClient?

    init(config: SourceConfig) {
        self.id = config.id
        self.config = config
    }

    func connect() async throws {
        guard let host = config.host, !host.isEmpty else {
            connectionState = .error("ホストが設定されていません。")
            throw FileSourceError.underlying("ホストが設定されていません。")
        }
        let username = config.username ?? ""
        let password = KeychainCredentialStore.password(for: config.id) ?? ""
        let port = config.port ?? 22

        connectionState = .connecting
        do {
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            let sftp = try await client.openSFTP()
            self.sshClient = client
            self.sftpClient = sftp
            connectionState = .connected
        } catch {
            connectionState = .error(error.localizedDescription)
            throw FileSourceError.underlying(error.localizedDescription)
        }
    }

    func rootPrefix(for category: ConsoleCategory) -> RelativePath {
        // No confirmed per-version split on the console side; the base path
        // (verified per-console via `basePathOverride`) is uniform for every category.
        .root
    }

    func list(_ path: RelativePath) async throws -> [FileEntry] {
        let sftp = try activeClient()
        let fullPath = remotePath(for: path)
        let names = try await sftp.listDirectory(atPath: fullPath)
        return names
            .flatMap(\.components)
            .filter { $0.filename != "." && $0.filename != ".." }
            .map { component in
                FileEntry(
                    name: component.filename,
                    isDirectory: Self.isDirectory(component),
                    size: component.attributes.size.map { Int64($0) },
                    modifiedDate: component.attributes.accessModificationTime?.modificationTime,
                    path: path.appending(component.filename)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// 512KB chunks so upload/download progress can be reported — a single
    /// `readAll()`/one-shot `write()` gives no visibility into how far a
    /// transfer over the network has gotten, which matters for the console
    /// link in particular (show files can be tens of MB).
    private static let chunkSize = 512 * 1024

    func copyIn(from localURL: URL, to path: RelativePath, progress: (@Sendable (Double) -> Void)?) async throws {
        let sftp = try activeClient()
        let totalSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? nil
        let destinationPath = remotePath(for: path.appending(localURL.lastPathComponent))

        guard let fileHandle = FileHandle(forReadingAtPath: localURL.path) else {
            throw FileSourceError.underlying("ローカルファイルを開けません: \(localURL.path)")
        }
        defer { try? fileHandle.close() }

        try await sftp.withFile(filePath: destinationPath, flags: [.write, .create, .truncate]) { file in
            var offset: UInt64 = 0
            while true {
                let chunk = try fileHandle.read(upToCount: Self.chunkSize) ?? Data()
                if chunk.isEmpty { break }
                try await file.write(ByteBuffer(data: chunk), at: offset)
                offset += UInt64(chunk.count)
                if let totalSize, totalSize > 0 {
                    progress?(min(1.0, Double(offset) / Double(totalSize)))
                }
            }
        }
        progress?(1.0)
    }

    func copyOut(from path: RelativePath, to localURL: URL, progress: (@Sendable (Double) -> Void)?) async throws {
        let sftp = try activeClient()
        let sourcePath = remotePath(for: path)
        let totalSize = try? await sftp.getAttributes(at: sourcePath).size

        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        FileManager.default.createFile(atPath: localURL.path, contents: nil)
        guard let fileHandle = FileHandle(forWritingAtPath: localURL.path) else {
            throw FileSourceError.underlying("ローカルファイルを作成できません: \(localURL.path)")
        }
        defer { try? fileHandle.close() }

        try await sftp.withFile(filePath: sourcePath, flags: .read) { file in
            var offset: UInt64 = 0
            while true {
                let buffer = try await file.read(from: offset, length: UInt32(Self.chunkSize))
                guard buffer.readableBytes > 0 else { break }
                fileHandle.write(Data(buffer: buffer))
                offset += UInt64(buffer.readableBytes)
                if let totalSize, totalSize > 0 {
                    progress?(min(1.0, Double(offset) / Double(totalSize)))
                }
                if buffer.readableBytes < Self.chunkSize { break }
            }
        }
        progress?(1.0)
    }

    func reveal(_ path: RelativePath) throws {
        throw FileSourceError.revealNotSupported
    }

    func updateName(_ newName: String) {
        config.name = newName
    }

    /// Best-effort discovery of onPC install folders on a machine reached
    /// over plain SSH (not the console) — there's no protocol-level way to
    /// ask "where is grandMA3 installed", so this just probes the handful
    /// of locations onPC is documented to use on Mac/Windows/Linux.
    /// Requires `connect()` to have already succeeded.
    func discoverOnPCVersionFolders(usernameHint: String) async -> [String] {
        guard let sftp = try? activeClient() else { return [] }
        var candidateRoots = [
            "/ProgramData/MALightingTechnology",
            "/C:/ProgramData/MALightingTechnology",
            "C:/ProgramData/MALightingTechnology",
        ]
        if !usernameHint.isEmpty {
            candidateRoots.insert(contentsOf: [
                "/Users/\(usernameHint)/MALightingTechnology",
                "/home/\(usernameHint)/MALightingTechnology",
            ], at: 0)
        }

        var results: [String] = []
        for root in candidateRoots {
            guard let names = try? await sftp.listDirectory(atPath: root) else { continue }
            let versionFolders = names
                .flatMap(\.components)
                .filter { $0.filename.hasPrefix("gma3_") && Self.isDirectory($0) }
                .map { "\(root)/\($0.filename)" }
            results.append(contentsOf: versionFolders)
        }
        return results
    }

    private func activeClient() throws -> SFTPClient {
        guard let sftpClient else {
            throw FileSourceError.notConnected
        }
        return sftpClient
    }

    private func remotePath(for path: RelativePath) -> String {
        let baseComponents = (config.basePathOverride ?? "")
            .split(separator: "/")
            .map(String.init)
        let allComponents = baseComponents + path.components
        return "/" + allComponents.joined(separator: "/")
    }

    private static func isDirectory(_ component: SFTPPathComponent) -> Bool {
        if let permissions = component.attributes.permissions {
            // POSIX S_IFMT mask (0o170000) / S_IFDIR (0o040000).
            return (permissions & 0o170000) == 0o040000
        }
        // Fallback: SFTP longname is an `ls -l`-style line; directories start with 'd'.
        return component.longname.first == "d"
    }
}
