import AppKit
import Foundation

/// Finds and starts the grandMA3 onPC app that belongs to an onPC data folder.
///
/// Data lives in `~/MALightingTechnology/gma3_2.5.1`, while the app is named
/// "grandMA3 onPC 2.5.1.1.app" (its `CFBundleShortVersionString` is "2.5.1"),
/// so they're matched by that version. An older install may be a plain
/// "grandMA3.app" with the version in the same field.
enum MA3Launcher {
    struct App {
        let url: URL
        let name: String
        let version: String
    }

    /// "gma3_2.5.1" -> "2.5.1"
    static func version(ofDataFolder name: String) -> String? {
        guard name.hasPrefix("gma3_") else { return nil }
        let v = String(name.dropFirst("gma3_".count))
        return v.first?.isNumber == true ? v : nil
    }

    /// Launching from here is offered from the 2.5 series on.
    static let firstSupportedVersion = [2, 5]

    /// "2.5.1" >= 2.5, "2.4.2" < 2.5 (compared number by number, so 2.10 > 2.5).
    static func isSupported(version: String) -> Bool {
        let parts = version.split(separator: ".").map { Int($0) ?? 0 }
        for (i, minimum) in firstSupportedVersion.enumerated() {
            let value = i < parts.count ? parts[i] : 0
            if value != minimum { return value > minimum }
        }
        return true
    }

    /// Whether this Source gets the "起動" menu item: an onPC version folder of 2.5 or later.
    static func supportsLaunch(_ config: SourceConfig) -> Bool {
        guard config.kind == .local, !config.isLibraryOnlyLocalSource, let path = config.path,
              let v = version(ofDataFolder: URL(fileURLWithPath: path).lastPathComponent) else { return false }
        return isSupported(version: v)
    }

    /// The app for a local Source (an onPC version folder), if installed.
    static func app(for config: SourceConfig) -> App? {
        guard config.kind == .local, !config.isLibraryOnlyLocalSource, let path = config.path,
              let version = version(ofDataFolder: URL(fileURLWithPath: path).lastPathComponent) else { return nil }
        return installedApps().first { $0.version == version }
    }

    /// grandMA3 onPC apps in /Applications and ~/Applications (Terminal clients excluded).
    static func installedApps() -> [App] {
        let fm = FileManager.default
        let folders = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var found: [App] = []
        for folder in folders {
            let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                guard name.hasPrefix("grandMA3"), !name.localizedCaseInsensitiveContains("terminal") else { continue }
                guard let bundle = Bundle(url: url),
                      let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                      !version.isEmpty else { continue }
                found.append(App(url: url, name: name, version: version))
            }
        }
        // Prefer the explicit "onPC" app when one version has several bundles.
        return found.sorted { ($0.name.contains("onPC") ? 0 : 1, $0.name) < ($1.name.contains("onPC") ? 0 : 1, $1.name) }
    }

    /// Starts the app (brings it forward if it's already running).
    @MainActor
    static func launch(_ app: App) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard let error else { return }
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "「\(app.name)」を起動できませんでした"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
