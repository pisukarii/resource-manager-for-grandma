import SwiftUI
import AppKit
import AVFoundation
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// What kind of preview/editor a file gets in the inspector pane.
enum ResourceKind {
    case image
    case video     // mp4 / m4v / mov (AVPlayer) and webm (WebKit)
    case text
    case fixture   // .gdtf (a zip holding description.xml + wheel images)
    case protectedFixture   // .pxml (grandMA2 fixture library; contents are encrypted)
    case other

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "tif", "tiff", "bmp", "heic"]
    private static let videoExtensions: Set<String> = ["mp4", "m4v", "mov", "webm"]
    private static let textExtensions: Set<String> = ["xml", "txt", "json", "lua", "csv", "log", "md"]

    static func of(_ fileName: String) -> ResourceKind {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if ext == "gdtf" { return .fixture }
        if ext == "pxml" { return .protectedFixture }
        if imageExtensions.contains(ext) { return .image }
        if videoExtensions.contains(ext) { return .video }
        if textExtensions.contains(ext) { return .text }
        return .other
    }
}

/// Bottom half of the file list: opens when a single file is selected, to
/// preview it and — for images such as GOBOs — swap it for another image.
/// Works on any `FileSource`; a file with no on-disk backing (SFTP) is
/// copied to a temp file first just to be shown.
struct ResourceInspectorView: View {
    @Environment(AppUIState.self) private var uiState
    let source: any FileSource
    let entry: FileEntry
    /// Called after the file on disk changed, so the list can re-read it.
    var onChanged: () -> Void
    var onClose: () -> Void

    private struct Loaded {
        var image: NSImage?
        var pixelSize: CGSize?
        var text: String?
        var note: String?
        var fixture: FixtureInfo?
        var fixtureXML: Data?          // description.xml (GDTF) or the whole fixture XML
        var videoURL: URL?
        var duration: Double?
        var slotImages: [String: NSImage] = [:]
    }

    private enum Backdrop: String, CaseIterable, Identifiable {
        case checker = "チェッカー"
        case dark = "黒"
        case light = "白"
        var id: String { rawValue }
    }

    @State private var loaded = Loaded()
    @State private var isLoading = false
    @State private var backdrop: Backdrop = .checker
    @State private var isDropTargeted = false
    @State private var isReplacing = false
    @State private var errorMessage: String?

    private var kind: ResourceKind { .of(entry.name) }
    private var canReplace: Bool { kind == .image && source.supportsDestructiveOperations }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let fixture = loaded.fixture, let xml = loaded.fixtureXML {
                // Fixture files get the full-width editor (tabs, DMX channel table).
                FixtureEditorView(
                    source: source,
                    entry: entry,
                    info: fixture,
                    slotImages: loaded.slotImages,
                    xmlData: xml,
                    sourceText: loaded.text,
                    resolveLocal: { await resolveLocalURL() },
                    onChanged: onChanged
                )
            } else {
                HStack(alignment: .top, spacing: 0) {
                    previewArea
                    Divider()
                    infoPanel
                        .frame(width: 230)
                }
            }
        }
        .background(.background)
        .task(id: "\(entry.id)|\(entry.modifiedDate?.timeIntervalSince1970 ?? 0)") {
            await load()
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: kind == .image ? "photo" : (kind == .video ? "film" : kind == .fixture || kind == .protectedFixture || loaded.fixture != nil ? "lightbulb.2" : (kind == .text ? "doc.text" : "doc")))
                .foregroundStyle(.secondary)
            Text(entry.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if canReplace {
                Button {
                    chooseReplacement()
                } label: {
                    Label("画像を差し替え...", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isReplacing)
            }
            Button {
                try? source.reveal(entry.path)
            } label: {
                Label("Finderで表示", systemImage: "folder")
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("エディターを閉じる")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Preview

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            switch kind {
            case .image:
                backdropView
                if let image = loaded.image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(16)
                } else if isLoading {
                    ProgressView()
                } else {
                    Text(loaded.note ?? "プレビューできません").foregroundStyle(.secondary)
                }
            case .fixture, .text:
                if let text = loaded.text {
                    ScrollView {
                        Text(text)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                } else if isLoading {
                    ProgressView()
                } else {
                    Text(loaded.note ?? "プレビューできません").foregroundStyle(.secondary)
                }
            case .video:
                if let url = loaded.videoURL {
                    VideoPreviewView(url: url)
                } else if isLoading {
                    ProgressView()
                } else {
                    Text(loaded.note ?? "プレビューできません").foregroundStyle(.secondary)
                }
            case .protectedFixture:
                protectedFixtureView
            case .other:
                VStack(spacing: 6) {
                    Image(systemName: "doc").font(.largeTitle).foregroundStyle(.secondary)
                    Text("この形式のプレビューには対応していません").foregroundStyle(.secondary)
                }
            }
            if canReplace {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 3 : 0)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard canReplace, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in await confirmAndReplace(with: url) }
            }
            return true
        }
        .overlay(alignment: .bottomLeading) {
            if kind == .image {
                Picker("背景", selection: $backdrop) {
                    ForEach(Backdrop.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private var backdropView: some View {
        switch backdrop {
        case .dark:
            Color.black
        case .light:
            Color.white
        case .checker:
            Canvas { context, size in
                let cell: CGFloat = 12
                for row in 0..<Int(ceil(size.height / cell)) {
                    for col in 0..<Int(ceil(size.width / cell)) {
                        let isLight = (row + col) % 2 == 0
                        let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        context.fill(Path(rect), with: .color(isLight ? Color(white: 0.30) : Color(white: 0.22)))
                    }
                }
            }
        }
    }

    // MARK: grandMA2 .pxml

    /// grandMA2's fixture library ships as `.pxml`, whose contents are
    /// encrypted (every file starts with unrelated random bytes), so there's
    /// nothing to parse — but the "manufacturer@model" file name still says
    /// what it is, and the file can be copied/moved/renamed like any other.
    private var protectedFixtureView: some View {
        let stem = (entry.name as NSString).deletingPathExtension
        let parts = stem.components(separatedBy: "@")
        let manufacturer = parts.count >= 2 ? parts[0] : ""
        let model = parts.count >= 2 ? parts.dropFirst().joined(separator: " @ ") : stem
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(model).font(.title3.bold())
                Text("grandMA2 PXML")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            if !manufacturer.isEmpty {
                Text("メーカー: \(manufacturer)").foregroundStyle(.secondary)
            }
            Label("中身は暗号化されているため、内容のプレビュー・編集はできません。", systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("同じ機種のGDTFを探す").font(.headline)
                HStack {
                    Button {
                        uiState.searchGDTFShare(fileName: entry.name, scope: .model)
                    } label: {
                        Label("機種名「\(GDTFShareSearch.searchWords(forFileName: entry.name))」で探す", systemImage: "magnifyingglass")
                    }
                    Button {
                        uiState.searchGDTFShare(fileName: entry.name, scope: .manufacturer)
                    } label: {
                        Text("メーカー名「\(GDTFShareSearch.searchWords(forFileName: entry.name, scope: .manufacturer))」で探す")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Info

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("名前", entry.name)
            if let size = entry.size {
                infoRow("サイズ", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
            }
            if let duration = loaded.duration {
                infoRow("長さ", String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60))
            }
            if let pixels = loaded.pixelSize {
                infoRow("画像サイズ", "\(Int(pixels.width)) × \(Int(pixels.height)) px")
            }
            if let date = entry.modifiedDate {
                infoRow("更新日時", date.formatted(date: .abbreviated, time: .shortened))
            }
            infoRow("場所", source.config.name)
            Spacer(minLength: 0)
            if canReplace {
                Text("差し替えたい画像をここにドラッグ&ドロップしても入れ替えられます。元のファイルはゴミ箱に移動します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if kind == .image {
                Text("このSourceでは画像の差し替えはできません(プレビューのみ)。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
        }
    }

    // MARK: Loading

    private func load() async {
        loaded = Loaded()
        guard kind != .other, kind != .protectedFixture else { return }
        isLoading = true
        defer { isLoading = false }

        if kind == .video {
            // Played straight from disk, so only Sources with a real local file
            // (onPC, USB) can preview — copying a large video out of SFTP just to look is too heavy.
            guard let url = source.localFileURL(for: entry.path) else {
                loaded.note = "動画のプレビューはローカル/USBのSourceのみ対応しています"
                return
            }
            loaded.videoURL = url
            if !VideoPreviewView.usesWebKit(url) {   // AVFoundation can't open WebM, so no metadata for it
                let asset = AVURLAsset(url: url)
                if let duration = try? await asset.load(.duration), duration.seconds.isFinite {
                    loaded.duration = duration.seconds
                }
                if let track = try? await asset.loadTracks(withMediaType: .video).first,
                   let size = try? await track.load(.naturalSize), size.width > 0 {
                    loaded.pixelSize = size
                }
            }
            return
        }

        let (url, tempDir) = await resolveLocalURL()
        defer { if let tempDir { try? FileManager.default.removeItem(at: tempDir) } }
        guard let url else {
            loaded.note = "ファイルを読み込めませんでした"
            return
        }

        switch kind {
        case .image:
            let result = await Task.detached(priority: .userInitiated) { () -> (NSImage?, CGSize?) in
                guard let image = NSImage(contentsOf: url) else { return (nil, nil) }
                var pixels: CGSize?
                if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
                    pixels = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
                }
                return (image, pixels)
            }.value
            loaded.image = result.0
            loaded.pixelSize = result.1
            if result.0 == nil { loaded.note = "画像として開けませんでした" }
        case .text:
            let result = await Task.detached(priority: .userInitiated) { () -> (String?, FixtureInfo?, Data?) in
                guard let handle = try? FileHandle(forReadingFrom: url) else { return (nil, nil, nil) }
                defer { try? handle.close() }
                // Up to 8 MB, enough for any fixture-type XML; only the head is shown as text.
                let data = (try? handle.read(upToCount: 8 * 1024 * 1024)) ?? Data()
                let fixture = String(decoding: data.prefix(4096), as: UTF8.self).contains("FixtureType")
                    ? FixtureParser.parse(xmlData: data, format: .ma3xml) : nil
                return (Self.sourceText(from: data), fixture, data)
            }.value
            loaded.text = result.0
            loaded.fixture = result.1
            if result.1 != nil { loaded.fixtureXML = result.2 }
        case .fixture:
            let result = await Task.detached(priority: .userInitiated) { () -> (String?, FixtureInfo?, [String: NSImage], Data?) in
                guard let data = try? GDTFArchive.description(of: url),
                      let info = FixtureParser.parse(xmlData: data, format: .gdtf) else { return (nil, nil, [:], nil) }
                var images: [String: NSImage] = [:]
                if let reader = ZipReader(url: url) {
                    for wheel in info.wheels {
                        for slot in wheel.slots {
                            guard let media = slot.mediaFileName else { continue }
                            // GDTF stores slot images as wheels/<MediaFileName>.png (or .svg);
                            // tolerate a name that already carries its extension.
                            let candidates = ["wheels/\(media).png", "wheels/\(media)", "wheels/\(media).svg",
                                              "wheels/\(media).jpg", "wheels/\(media).jpeg"]
                            for candidate in candidates {
                                if let bytes = reader.read(candidate), let image = NSImage(data: bytes) {
                                    images[slot.id] = image
                                    break
                                }
                            }
                        }
                    }
                }
                return (Self.sourceText(from: data), info, images, data)
            }.value
            loaded.text = result.0
            loaded.fixture = result.1
            loaded.slotImages = result.2
            loaded.fixtureXML = result.3
            if result.1 == nil { loaded.note = "GDTFとして読み込めませんでした(zipが壊れている可能性があります)" }
        case .protectedFixture, .video, .other:
            break
        }
    }

    /// First ~64 KB of an XML file as text (BOM stripped), for the source view.
    nonisolated private static func sourceText(from data: Data) -> String {
        var text = String(decoding: data.prefix(64 * 1024), as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        if data.count > 64 * 1024 { text += "\n\n…(先頭64KBのみ表示)" }
        return text
    }

    /// The on-disk file to read, plus a temp directory to clean up when the
    /// Source has no local backing and the file had to be copied out.
    private func resolveLocalURL() async -> (URL?, URL?) {
        if let local = source.localFileURL(for: entry.path) { return (local, nil) }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent(entry.name)
        do {
            try await source.copyOut(from: entry.path, to: tempURL)
            return (tempURL, tempDir)
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            return (nil, nil)
        }
    }

    // MARK: Replace

    private func chooseReplacement() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "差し替え"
        panel.message = "「\(entry.name)」と入れ替える画像を選んでください"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await confirmAndReplace(with: url) }
    }

    private func confirmAndReplace(with newURL: URL) async {
        guard canReplace, !isReplacing else { return }
        guard NSImage(contentsOf: newURL) != nil else {
            errorMessage = "選んだファイルは画像として開けませんでした。"
            return
        }

        let alert = NSAlert()
        alert.messageText = "「\(entry.name)」を差し替えますか？"
        alert.informativeText = "「\(newURL.lastPathComponent)」の内容で入れ替えます。元のファイルはゴミ箱に移動します(Finderから戻せます)。ファイル名は変わりません。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "差し替える")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isReplacing = true
        defer { isReplacing = false }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            // Built under the original name first, so a failure here leaves
            // the original untouched.
            let prepared = tempDir.appendingPathComponent(entry.name)
            try Self.prepareReplacement(from: newURL, as: entry.name, to: prepared)

            let parent = RelativePath(components: Array(entry.path.components.dropLast()))
            try await source.delete(entry.path)          // -> Trash
            try await source.copyIn(from: prepared, to: parent)
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Writes `source` to `destination` in the format implied by `targetName`'s
    /// extension, so the swapped-in image keeps working under the same
    /// filename that fixture/gobo definitions reference.
    private static func prepareReplacement(from source: URL, as targetName: String, to destination: URL) throws {
        func normalized(_ ext: String) -> String {
            let e = ext.lowercased()
            return e == "jpeg" ? "jpg" : e
        }
        let targetExt = normalized((targetName as NSString).pathExtension)
        let sourceExt = normalized(source.pathExtension)
        if targetExt == sourceExt {
            try FileManager.default.copyItem(at: source, to: destination)
            return
        }
        guard let image = NSImage(contentsOf: source),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw FileSourceError.underlying("画像を読み込めませんでした。")
        }
        let data: Data?
        switch targetExt {
        case "png": data = rep.representation(using: .png, properties: [:])
        case "jpg": data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
        default:
            throw FileSourceError.underlying("「.\(targetExt)」形式への変換には対応していません。同じ形式(.\(targetExt))の画像を選んでください。")
        }
        guard let data else { throw FileSourceError.underlying("画像の変換に失敗しました。") }
        try data.write(to: destination)
    }
}

/// Small async thumbnail for image rows in the file list (QuickLook,
/// cached) — makes browsing thousands of GOBO images practical.
struct FileThumbnailView: View {
    let url: URL
    var side: CGFloat = 26

    @State private var image: CGImage?

    private static let cache = NSCache<NSURL, CGImage>()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.18))
            if let image {
                Image(decorative: image, scale: 2)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: side, height: side)
        .task(id: url) {
            if let cached = Self.cache.object(forKey: url as NSURL) {
                image = cached
                return
            }
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: side, height: side),
                scale: 2,
                representationTypes: .thumbnail
            )
            if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                let cg = rep.cgImage
                Self.cache.setObject(cg, forKey: url as NSURL)
                image = cg
            }
        }
    }
}
