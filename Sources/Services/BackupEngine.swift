import Foundation
import AppKit
import Observation

// MARK: - What to back up

enum BackupScope: String, CaseIterable, Identifiable {
    case library    // shows + backups + fixture library + resource + gma3_library
    case showsOnly  // just the show files
    var id: String { rawValue }
}

/// One folder to copy, and where it lands inside the backup folder. The
/// destination mirrors the onPC/USB layout (e.g. `gma3_2.5.1/shared/shows`,
/// `gma3_library`), so the files are stored exactly as MA keeps them and can
/// be copied back as they are — nothing is zipped or converted.
struct BackupItem: Hashable {
    let sourceURL: URL
    let destination: [String]

    var title: String { destination.joined(separator: "/") }
}

struct BackupPlan {
    let items: [BackupItem]
    /// Why something wasn't included (shown to the user).
    let notes: [String]

    var isEmpty: Bool { items.isEmpty }

    /// Local (onPC) and USB Sources are plain folders; an SFTP console isn't backed up.
    static func isSupported(_ config: SourceConfig) -> Bool {
        (config.kind == .local || config.kind == .usb) && config.path != nil
    }

    /// App files (`onpc`, `systemapp`, `ma`, `shared/language`, installers) are
    /// never included — only library-type data.
    static func make(for config: SourceConfig, scope: BackupScope) -> BackupPlan {
        guard isSupported(config), let path = config.path else {
            return BackupPlan(items: [], notes: ["このSourceはバックアップに対応していません。"])
        }
        var items: [BackupItem] = []
        var notes: [String] = []
        let root = URL(fileURLWithPath: path)

        func addIfDirectory(_ url: URL, _ destination: [String], nonEmptyOnly: Bool = false) -> Bool {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return false }
            if nonEmptyOnly, ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).isEmpty { return false }
            items.append(BackupItem(sourceURL: url, destination: destination))
            return true
        }

        switch config.kind {
        case .local:
            if config.isLibraryOnlyLocalSource {
                if scope == .showsOnly {
                    notes.append("共有ライブラリにはショーファイルがありません。")
                } else {
                    _ = addIfDirectory(root, [root.lastPathComponent])
                }
            } else {
                let version = root.lastPathComponent
                let shared = root.appendingPathComponent("shared", isDirectory: true)
                if scope == .showsOnly {
                    if !addIfDirectory(shared.appendingPathComponent("shows"), [version, "shared", "shows"]) {
                        notes.append("ショーフォルダが見つかりません。")
                    }
                } else {
                    for name in ["shows", "backups", "lib_fixture_types", "resource"] {
                        _ = addIfDirectory(shared.appendingPathComponent(name), [version, "shared", name])
                    }
                    _ = addIfDirectory(root.appendingPathComponent("gma3_library"), [version, "gma3_library"], nonEmptyOnly: true)
                    _ = addIfDirectory(root.deletingLastPathComponent().appendingPathComponent("gma3_library"), ["gma3_library"])
                }
            }
        case .usb:
            let dataName = root.lastPathComponent
            if scope == .showsOnly {
                let candidates: [([String], URL)] = [
                    (["shared", "shows"], root.appendingPathComponent("shared").appendingPathComponent("shows")),
                    (["shows"], root.appendingPathComponent("shows")),
                ]
                if !candidates.contains(where: { addIfDirectory($0.1, [dataName] + $0.0) }) {
                    notes.append("ショーフォルダが見つかりません。")
                }
            } else {
                _ = addIfDirectory(root, [dataName])
            }
        case .sftp:
            break
        }
        if items.isEmpty && notes.isEmpty { notes.append("バックアップできるフォルダが見つかりません。") }
        return BackupPlan(items: items, notes: notes)
    }
}

// MARK: - Copy engine

struct BackupProgress: Sendable {
    var doneBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var doneFiles = 0
    var totalFiles = 0
    var currentFile = ""
}

enum BackupError: Error {
    case cancelled
    case notEnoughSpace(needed: Int64, available: Int64)
    case destination(String)       // can't write to the USB: stop
}

enum BackupEngine {
    struct FileJob {
        let source: URL
        let destination: [String]
        let size: Int64
        let modified: Date?
    }

    struct Scan {
        var directories: [[String]] = []
        var files: [FileJob] = []
        var skippedLinks = 0
        var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }
    }

    private static let skippedNames: Set<String> = [".DS_Store", ".localized", ".Trashes", ".fseventsd", ".Spotlight-V100", ".TemporaryItems"]

    /// Lists everything under `items` (symlinks and Finder/cloud junk are left out).
    static func scan(_ items: [BackupItem]) -> Scan {
        var scan = Scan()
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        for item in items {
            scan.directories.append(item.destination)
            let base = item.sourceURL.standardizedFileURL.pathComponents
            guard let enumerator = fm.enumerator(at: item.sourceURL, includingPropertiesForKeys: keys, options: []) else { continue }
            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                if skippedNames.contains(name) || name.hasPrefix(".tmp.") || name.hasPrefix("._") {
                    if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { enumerator.skipDescendants() }
                    continue
                }
                let values = try? url.resourceValues(forKeys: Set(keys))
                if values?.isSymbolicLink == true { scan.skippedLinks += 1; continue }
                let relative = Array(url.standardizedFileURL.pathComponents.dropFirst(base.count))
                if values?.isDirectory == true {
                    scan.directories.append(item.destination + relative)
                } else {
                    scan.files.append(FileJob(
                        source: url, destination: item.destination + relative,
                        size: Int64(values?.fileSize ?? 0), modified: values?.contentModificationDate))
                }
            }
        }
        return scan
    }

    /// Copies `scan` into `folder` in chunks (so progress is smooth even for
    /// a 100 MB file). A file that can't be *read* is recorded and skipped; a
    /// failure *writing* to the USB (full, unplugged, read-only) stops the run.
    static func copy(
        _ scan: Scan, into folder: URL,
        isCancelled: () -> Bool,
        progress: (BackupProgress) -> Void
    ) throws -> (copiedFiles: Int, copiedBytes: Int64, unreadable: [String]) {
        let fm = FileManager.default
        var state = BackupProgress(totalBytes: scan.totalBytes, totalFiles: scan.files.count)
        var unreadable: [String] = []
        var lastReport = Date.distantPast
        func report(force: Bool = false) {
            let now = Date()
            if force || now.timeIntervalSince(lastReport) > 0.1 { lastReport = now; progress(state) }
        }

        do {
            for directory in scan.directories {
                try fm.createDirectory(at: directory.reduce(folder) { $0.appendingPathComponent($1) },
                                       withIntermediateDirectories: true)
            }
        } catch {
            throw BackupError.destination(error.localizedDescription)
        }

        let chunk = 4 * 1024 * 1024
        for job in scan.files {
            if isCancelled() { throw BackupError.cancelled }
            state.currentFile = job.destination.joined(separator: "/")
            report()
            let target = job.destination.reduce(folder) { $0.appendingPathComponent($1) }

            guard let input = try? FileHandle(forReadingFrom: job.source) else {
                unreadable.append(job.destination.joined(separator: "/"))
                state.doneFiles += 1; state.doneBytes += job.size
                continue
            }
            defer { try? input.close() }
            guard fm.createFile(atPath: target.path, contents: nil), let output = try? FileHandle(forWritingTo: target) else {
                throw BackupError.destination("「\(target.lastPathComponent)」をUSBに作成できませんでした。")
            }
            var written: Int64 = 0
            do {
                while true {
                    if isCancelled() { try? output.close(); throw BackupError.cancelled }
                    guard let data = try input.read(upToCount: chunk), !data.isEmpty else { break }
                    do { try output.write(contentsOf: data) }
                    catch { try? output.close(); throw BackupError.destination(error.localizedDescription) }
                    written += Int64(data.count)
                    state.doneBytes += Int64(data.count)
                    report()
                }
                try output.close()
            } catch let error as BackupError {
                throw error
            } catch {
                // read failed part-way: drop the half-written file and carry on
                try? fm.removeItem(at: target)
                unreadable.append(job.destination.joined(separator: "/"))
                state.doneFiles += 1
                continue
            }
            if let modified = job.modified {
                try? fm.setAttributes([.modificationDate: modified], ofItemAtPath: target.path)
            }
            state.doneFiles += 1
            report()
        }
        report(force: true)
        return (scan.files.count - unreadable.count, state.doneBytes, unreadable)
    }

    /// Today's date as the app writes it: 2026-11-17 -> "261117-MAbackup".
    static func baseFolderName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyMMdd"
        return "\(formatter.string(from: date))-MAbackup"
    }

    /// The date-named folder, or "-2", "-3"… if one from today already exists on the USB.
    static func folderName(in volume: URL, date: Date = Date()) -> String {
        let base = baseFolderName(date: date)
        var name = base
        var n = 2
        while FileManager.default.fileExists(atPath: volume.appendingPathComponent(name).path) {
            name = "\(base)-\(n)"
            n += 1
        }
        return name
    }
}

// MARK: - Which USB

struct ExternalVolume: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let name: String
    let totalBytes: Int64?
    let freeBytes: Int64?
    /// Already holds a grandMA3 / gma2 folder (an MA USB stick).
    let hasMAFolder: Bool

    /// Mounted external/removable volumes (the boot disk is never listed).
    static func list(excludingContaining sourcePath: String? = nil) -> [ExternalVolume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeIsInternalKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url -> ExternalVolume? in
            guard url.path != "/", let v = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let external = (v.volumeIsInternal == false) || v.volumeIsRemovable == true || v.volumeIsEjectable == true
            guard external else { return nil }
            if let sourcePath, sourcePath.hasPrefix(url.path + "/") { return nil }   // not the volume being backed up
            let hasMA = ["grandMA3", "gma2"].contains { FileManager.default.fileExists(atPath: url.appendingPathComponent($0).path) }
            return ExternalVolume(
                url: url, name: v.volumeName ?? url.lastPathComponent,
                totalBytes: v.volumeTotalCapacity.map(Int64.init),
                freeBytes: v.volumeAvailableCapacityForImportantUsage,
                hasMAFolder: hasMA)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Running a backup (UI state)

/// Cancellation that reaches the copy loop. (`Task.detached` doesn't inherit
/// its parent's cancellation, so the Cancel button sets this instead.)
final class BackupCancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set() { lock.lock(); value = true; lock.unlock() }
}

@MainActor
@Observable
final class BackupJob {
    enum Phase: Equatable {
        case idle, scanning, copying
        case finished(files: Int, bytes: Int64)
        case cancelled
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var progress = BackupProgress()
    private(set) var folderURL: URL?
    private(set) var unreadable: [String] = []

    private var task: Task<Void, Never>?
    private var cancelFlag = BackupCancelFlag()

    var isRunning: Bool { phase == .scanning || phase == .copying }

    func start(plan: BackupPlan, volume: ExternalVolume) {
        guard !isRunning else { return }
        phase = .scanning
        cancelFlag = BackupCancelFlag()
        let flag = cancelFlag
        progress = BackupProgress()
        unreadable = []
        folderURL = nil
        let items = plan.items

        task = Task { [weak self] in
            // Scan, then work out the folder, in the background.
            let (scan, folder): (BackupEngine.Scan, URL) = await Task.detached(priority: .userInitiated) {
                let scan = BackupEngine.scan(items)
                let name = BackupEngine.folderName(in: volume.url)
                return (scan, volume.url.appendingPathComponent(name, isDirectory: true))
            }.value

            guard let self else { return }
            let free = (try? volume.url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
                .volumeAvailableCapacityForImportantUsage
            if let free, scan.totalBytes > free {
                self.phase = .failed("USBの空き容量が足りません(必要 \(Self.size(scan.totalBytes)) / 空き \(Self.size(free)))。")
                return
            }
            if scan.files.isEmpty && scan.directories.isEmpty {
                self.phase = .failed("コピーするファイルがありません。")
                return
            }

            self.phase = .copying
            self.progress = BackupProgress(totalBytes: scan.totalBytes, totalFiles: scan.files.count)
            self.folderURL = folder

            let outcome: Result<(Int, Int64, [String]), Error> = await Task.detached(priority: .userInitiated) {
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                    let result = try BackupEngine.copy(
                        scan, into: folder,
                        isCancelled: { flag.isSet },
                        progress: { p in Task { @MainActor [weak self] in self?.progress = p } })
                    return .success((result.copiedFiles, result.copiedBytes, result.unreadable))
                } catch {
                    return .failure(error)
                }
            }.value

            switch outcome {
            case .success(let result):
                self.unreadable = result.2
                self.phase = .finished(files: result.0, bytes: result.1)
            case .failure(let error):
                // An unfinished backup must not look like a good one: remove what we made.
                try? FileManager.default.removeItem(at: folder)
                self.folderURL = nil
                switch error {
                case BackupError.cancelled: self.phase = .cancelled
                case BackupError.destination(let message): self.phase = .failed("USBに書き込めませんでした: \(message)")
                default: self.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    func cancel() {
        cancelFlag.set()
        task?.cancel()
    }

    nonisolated static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
