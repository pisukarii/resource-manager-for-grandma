import Foundation

/// Finds installed grandMA3 onPC version folders under `~/MALightingTechnology`.
enum MA3LocalDetector {
    static var malightingRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MALightingTechnology", isDirectory: true)
    }

    struct VersionFolder: Identifiable, Hashable {
        var id: String { url.path }
        let name: String
        let url: URL
    }

    static func detectVersionFolders() -> [VersionFolder] {
        let root = malightingRoot
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            guard url.lastPathComponent.hasPrefix("gma3_") else { return nil }
            // A real version folder has either a shared/ or gma3_library/ subfolder.
            let hasShared = FileManager.default.fileExists(atPath: url.appendingPathComponent("shared").path)
            let hasLibrary = FileManager.default.fileExists(atPath: url.appendingPathComponent("gma3_library").path)
            guard hasShared || hasLibrary else { return nil }
            return VersionFolder(name: url.lastPathComponent, url: url)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }
}
