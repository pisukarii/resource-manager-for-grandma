import Foundation
import AppKit
import Observation

/// A USB volume found to contain a recognized console's marker folder
/// (`grandMA3` or `gma2`), along with the data-root folder to use as that
/// Source's `path` and which family it belongs to.
struct DetectedUSBSource: Identifiable, Hashable {
    var id: String { dataRootURL.path }
    let volumeURL: URL
    let dataRootURL: URL
    let family: ConsoleFamily
}

/// Watches for USB volumes containing a `grandMA3` or `gma2` folder and
/// surfaces the most recently mounted one that isn't already a configured
/// Source, so the UI can offer a one-tap "add as Source" banner.
@MainActor
@Observable
final class USBVolumeWatcher {
    private(set) var pendingDetection: DetectedUSBSource?

    private let store: SourceStore
    private var observer: NSObjectProtocol?

    init(store: SourceStore) {
        self.store = store
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            Task { @MainActor in
                self?.evaluate(volumeURL)
            }
        }
        // Catch a USB stick that was already inserted before launch.
        for volume in Self.mountedVolumeURLs() {
            evaluate(volume)
        }
    }

    // Lives for the app's lifetime (owned by the App scene), so the
    // notification observer is intentionally never torn down.

    func dismissPending() {
        pendingDetection = nil
    }

    private func evaluate(_ volumeURL: URL) {
        guard let detected = Self.detectConsoleFolder(at: volumeURL) else { return }
        let alreadyConfigured = store.configs.contains { $0.path == detected.dataRootURL.path }
        guard !alreadyConfigured else { return }
        pendingDetection = detected
    }

    static func detectConsoleFolder(at volumeURL: URL) -> DetectedUSBSource? {
        for family in ConsoleFamily.allCases {
            let root = volumeURL.appendingPathComponent(family.usbRootFolderName, isDirectory: true)
            if FileManager.default.fileExists(atPath: root.path) {
                return DetectedUSBSource(volumeURL: volumeURL, dataRootURL: root, family: family)
            }
        }
        return nil
    }

    static func detectMountedConsoleVolumes() -> [DetectedUSBSource] {
        mountedVolumeURLs().compactMap(detectConsoleFolder(at:))
    }

    private static func mountedVolumeURLs() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil)) ?? []
    }
}
