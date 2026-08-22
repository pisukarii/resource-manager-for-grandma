import Foundation
import Observation

@MainActor
@Observable
final class SourceStore {
    private(set) var configs: [SourceConfig] = []
    private var liveSources: [UUID: any FileSource] = [:]

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("GrandMAResourceManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("sources.json")
        Self.migrateLegacyStorageIfNeeded(to: storageURL, appSupport: appSupport)
        load()
    }

    /// One-time carry-forward from the pre-rename ("Quick File Open for
    /// MA3") Application Support folder, so already-configured Sources
    /// aren't silently lost after the app rename.
    private static func migrateLegacyStorageIfNeeded(to newStorageURL: URL, appSupport: URL) {
        guard !FileManager.default.fileExists(atPath: newStorageURL.path) else { return }
        let legacyURL = appSupport.appendingPathComponent("QuickFileOpenForMA3/sources.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        try? FileManager.default.copyItem(at: legacyURL, to: newStorageURL)
    }

    var sources: [any FileSource] {
        configs.compactMap { liveSources[$0.id] }
    }

    func source(for id: UUID) -> (any FileSource)? {
        liveSources[id]
    }

    func addSource(_ config: SourceConfig) {
        configs.append(config)
        instantiate(config)
        save()
    }

    /// Replaces a Source's full configuration (host/port/username/base path
    /// for SFTP) and re-instantiates its live backend with the new
    /// settings, so e.g. editing a console's IP address or credentials
    /// takes effect immediately without deleting and re-adding the Source.
    func updateSource(_ config: SourceConfig) {
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[index] = config
        liveSources.removeValue(forKey: config.id)
        instantiate(config)
        save()
    }

    func renameSource(id: UUID, to newName: String) {
        guard let index = configs.firstIndex(where: { $0.id == id }), !newName.isEmpty else { return }
        configs[index].name = newName
        liveSources[id]?.updateName(newName)
        save()
    }

    func removeSource(id: UUID) {
        configs.removeAll { $0.id == id }
        liveSources.removeValue(forKey: id)
        KeychainCredentialStore.deletePassword(for: id)
        save()
    }

    private func instantiate(_ config: SourceConfig) {
        switch config.kind {
        case .local:
            // config.path points at the chosen gma3_x.y.z version folder;
            // gma3_library is a sibling of that folder, shared across versions.
            guard let path = config.path else { return }
            let versionURL = URL(fileURLWithPath: path)
            let malightingRoot = versionURL.deletingLastPathComponent()
            let versionName = versionURL.lastPathComponent
            liveSources[config.id] = DiskFileSource(config: config, rootURL: malightingRoot) { category in
                category.rootKind == .versionScoped ? RelativePath(versionName) : .root
            }
        case .usb:
            // config.path already points at <volume>/grandMA3; every category
            // sits directly under it, no per-version split on USB.
            guard let path = config.path else { return }
            liveSources[config.id] = DiskFileSource(config: config, rootURL: URL(fileURLWithPath: path)) { _ in .root }
        case .sftp:
            KeychainCredentialStore.migrateLegacyPasswordIfNeeded(for: config.id)
            let source = ConsoleSFTPSource(config: config)
            liveSources[config.id] = source
            // Best-effort proactive connect so the sidebar's connection dot
            // reflects real status without requiring the user to select
            // this Source first.
            Task { try? await source.connect() }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([SourceConfig].self, from: data) else {
            return
        }
        configs = decoded
        for config in decoded {
            instantiate(config)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
