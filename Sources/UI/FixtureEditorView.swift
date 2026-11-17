import SwiftUI
import AppKit

// MARK: - Draft (in-memory only)

/// Unsaved edits to one fixture file. Lives only in memory: nothing touches
/// the file system until the user chooses "コピーとして保存", and even then
/// the result is a new "… custom vN" file — the original is never modified.
@MainActor
@Observable
final class FixtureDraft {
    let originalModes: [DMXModeChannels]
    var modes: [DMXModeChannels]
    /// GOBO slot id (`FixtureInfo.Slot.id`) -> new PNG data, GDTF only.
    var stagedSlotImages: [String: Data] = [:]

    init(modes: [DMXModeChannels]) {
        originalModes = modes
        self.modes = modes
    }

    var hasChanges: Bool { modes != originalModes || !stagedSlotImages.isEmpty }

    func discard() {
        modes = originalModes
        stagedSlotImages = [:]
    }
}

/// Keeps a file's draft while the user looks at other files, so switching
/// selection doesn't silently throw edits away.
@MainActor
final class FixtureDraftStore {
    static let shared = FixtureDraftStore()
    private var drafts: [String: FixtureDraft] = [:]

    func draft(key: String, original: [DMXModeChannels]) -> FixtureDraft {
        if let existing = drafts[key], existing.originalModes == original { return existing }
        let fresh = FixtureDraft(modes: original)
        drafts[key] = fresh
        return fresh
    }

    func remove(key: String) { drafts[key] = nil }
}

// MARK: - Editor

/// Fixture type editor in the inspector pane: 概要 (modes, wheels, GOBO
/// images), DMXチャンネル (the editor's channel table), and the XML source.
struct FixtureEditorView: View {
    let source: any FileSource
    let entry: FileEntry
    let info: FixtureInfo
    /// Slot images already in the file, by `FixtureInfo.Slot.id`.
    let slotImages: [String: NSImage]
    /// description.xml (GDTF) or the whole file (grandMA3 XML).
    let xmlData: Data
    let sourceText: String?
    /// The file on local disk (copied out first if the Source isn't local),
    /// plus a temp directory to delete afterwards.
    let resolveLocal: () async -> (URL?, URL?)
    var onChanged: () -> Void

    private enum Tab: String, CaseIterable, Identifiable {
        case overview = "概要"
        case channels = "DMXチャンネル"
        case xml = "XML"
        var id: String { rawValue }
    }

    @State private var draft: FixtureDraft?
    @State private var tab: Tab = .overview
    @State private var nextName = ""
    @State private var isSaving = false
    @State private var message: String?
    @State private var errorMessage: String?

    private var key: String { "\(source.id)|\(entry.id)" }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if let draft, draft.hasChanges { saveBar(draft) }
            Divider()
            content
        }
        .task(id: key) {
            draft = FixtureDraftStore.shared.draft(
                key: key, original: FixtureChannelEditor.parseModes(xmlData: xmlData, format: info.format))
        }
        .task(id: draft?.hasChanges ?? false) {
            if draft?.hasChanges == true { nextName = await customName() }
        }
        .alert("保存しました", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
        .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: Chrome

    private var toolbar: some View {
        HStack {
            Picker("表示", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func saveBar(_ draft: FixtureDraft) -> some View {
        let problems = draft.modes.enumerated().flatMap { _, mode in
            DMXChannelValidator.problems(in: mode, format: info.format).values
        }
        return HStack(spacing: 10) {
            Image(systemName: "pencil.circle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("未保存の変更があります").font(.callout.weight(.semibold))
                Text(problems.isEmpty
                     ? "保存すると「\(nextName.isEmpty ? "…" : nextName)」という新しいファイルを作ります。元のファイルは変更しません。"
                     : "重複や範囲外のアドレスがあるため保存できません(赤い行を確認してください)。")
                    .font(.caption)
                    .foregroundStyle(problems.isEmpty ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
            Spacer()
            Button("変更を破棄") { draft.discard() }
                .disabled(isSaving)
            Button {
                Task { await saveCopy(draft) }
            } label: {
                Label("コピーとして保存", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || !problems.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .overview:
            FixtureDetailView(
                info: info,
                images: mergedImages,
                stagedIDs: Set(draft?.stagedSlotImages.keys ?? [:].keys),
                canEdit: info.format == .gdtf,
                onReplaceSlot: { chooseSlotImage($0) }
            )
        case .channels:
            if let draft {
                DMXChannelTableView(draft: draft, format: info.format)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .xml:
            ScrollView {
                Text(sourceText ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    /// Existing slot images, with staged replacements shown in their place.
    private var mergedImages: [String: NSImage] {
        var images = slotImages
        for (id, data) in draft?.stagedSlotImages ?? [:] {
            if let image = NSImage(data: data) { images[id] = image }
        }
        return images
    }

    // MARK: GOBO slot images (staged, not written)

    private func chooseSlotImage(_ slot: FixtureInfo.Slot) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "選択"
        panel.message = "GOBO「\(slot.name)」に使う画像を選んでください(「コピーとして保存」するまでファイルには反映されません)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            errorMessage = "選んだファイルは画像として開けませんでした。"
            return
        }
        draft?.stagedSlotImages[slot.id] = png
    }

    // MARK: Save as a new copy

    /// "<name> custom v1.<ext>", or the next free vN — never an existing file.
    private func customName() async -> String {
        let ns = entry.name as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension.replacingOccurrences(
            of: #" custom v\d+$"#, with: "", options: .regularExpression)
        let parent = RelativePath(components: Array(entry.path.components.dropLast()))
        var n = 1
        while true {
            let name = ext.isEmpty ? "\(stem) custom v\(n)" : "\(stem) custom v\(n).\(ext)"
            if !(await source.exists(parent.appending(name))) { return name }
            n += 1
        }
    }

    private func saveCopy(_ draft: FixtureDraft) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let newName = await customName()
            let prepared = tempDir.appendingPathComponent(newName)
            var edited = try FixtureChannelEditor.apply(
                edited: draft.modes, original: draft.originalModes, to: xmlData, format: info.format)

            switch info.format {
            case .ma3xml:
                try edited.write(to: prepared)
            case .gdtf:
                let (archive, archiveTemp) = await resolveLocal()
                defer { if let archiveTemp { try? FileManager.default.removeItem(at: archiveTemp) } }
                guard let archive else { throw FileSourceError.underlying("元のGDTFを読み込めませんでした。") }

                var entries: [String: Data] = [:]
                let used = GDTFArchive.entryNames(of: archive)
                var taken = used
                for slot in info.wheels.flatMap(\.slots) {
                    guard let png = draft.stagedSlotImages[slot.id] else { continue }
                    let media: String
                    if let existing = slot.mediaFileName {
                        media = existing
                    } else {
                        // A slot with no image yet: an unused file name, recorded in description.xml.
                        let base = Self.safeFileName(slot.name.isEmpty ? "gobo" : slot.name)
                        var candidate = base
                        var n = 2
                        while taken.contains("wheels/\(candidate).png") { candidate = "\(base)_\(n)"; n += 1 }
                        media = candidate
                        edited = try FixtureParser.settingMediaFileName(
                            media, wheelIndex: slot.wheelIndex, slotIndex: slot.slotIndex, in: edited)
                    }
                    taken.insert("wheels/\(media).png")
                    entries["wheels/\(media).png"] = png
                }
                entries["description.xml"] = edited
                try GDTFArchive.writeUpdatedCopy(of: archive, entries: entries, to: prepared)
            }

            let parent = RelativePath(components: Array(entry.path.components.dropLast()))
            try await source.copyIn(from: prepared, to: parent)   // new file only; the original is never touched
            FixtureDraftStore.shared.remove(key: key)
            let fresh = FixtureDraft(modes: draft.modes)
            self.draft = fresh
            onChanged()
            message = "「\(newName)」として保存しました。\n元のファイル「\(entry.name)」は変更していません。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func safeFileName(_ name: String) -> String {
        String(name.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
    }
}

// MARK: - DMXChannels table

struct DMXChannelTableView: View {
    @Bindable var draft: FixtureDraft
    let format: FixtureInfo.Format

    @State private var modeIndex = 0
    @State private var expanded: Set<Int> = []

    private var caps: DMXChannelCapabilities { .of(format) }
    private var safeIndex: Int { min(modeIndex, max(draft.modes.count - 1, 0)) }
    private var problems: [Int: String] {
        draft.modes.indices.contains(safeIndex)
            ? DMXChannelValidator.problems(in: draft.modes[safeIndex], format: format) : [:]
    }

    private enum W {
        static let expander: CGFloat = 22
        static let number: CGFloat = 36
        static let name: CGFloat = 190
        static let attribute: CGFloat = 130
        static let small: CGFloat = 52
        static let value: CGFloat = 60
        static let snap: CGFloat = 44
    }

    var body: some View {
        if draft.modes.isEmpty {
            Text("DMXモードがありません").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("モード").font(.caption).foregroundStyle(.secondary)
                    Picker("モード", selection: $modeIndex) {
                        ForEach(Array(draft.modes.enumerated()), id: \.offset) { index, mode in
                            Text("\(mode.name.isEmpty ? "(名前なし)" : mode.name) — \(mode.rows.count) ch").tag(index)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                    Spacer()
                    Text(format == .gdtf ? "GDTF: Lowlight列は保存できません" : "MA3 XML: DMX Break列は保存できません")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                Divider()
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(draft.modes[safeIndex].rows.indices, id: \.self) { i in
                                rowView(i)
                                if expanded.contains(i) { functionsView(draft.modes[safeIndex].rows[i]) }
                                Divider().opacity(0.4)
                            }
                        } header: {
                            headerRow
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: Rows

    private var headerRow: some View {
        HStack(spacing: 4) {
            Spacer().frame(width: W.expander)
            head("No", W.number)
            head("Name", W.name, leading: true)
            head("Attribute", W.attribute, leading: true)
            head("DMX Break", W.small + 14)
            head("Coarse", W.small)
            head("Fine", W.small)
            head("Ultra", W.small)
            head("Default", W.value)
            head("Highlight", W.value + 8)
            head("Lowlight", W.value + 6)
            head("Snap", W.snap)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private func head(_ title: String, _ width: CGFloat, leading: Bool = false) -> some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .frame(width: width, alignment: leading ? .leading : .center)
    }

    private func rowView(_ i: Int) -> some View {
        let row = draft.modes[safeIndex].rows[i]
        let original = draft.originalModes[safeIndex].rows[i]
        let bad = problems[row.id]
        return HStack(spacing: 4) {
            Button {
                if expanded.contains(i) { expanded.remove(i) } else { expanded.insert(i) }
            } label: {
                Image(systemName: expanded.contains(i) ? "chevron.down" : "chevron.right")
                    .font(.caption2).frame(width: W.expander)
            }
            .buttonStyle(.plain)
            .disabled(row.functions.isEmpty)
            Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: W.number)
            Text(row.name.isEmpty ? "—" : row.name).lineLimit(1).truncationMode(.middle).frame(width: W.name, alignment: .leading)
                .help(row.name)
            Text(row.attribute).foregroundStyle(.secondary).lineLimit(1).frame(width: W.attribute, alignment: .leading)

            if caps.hasBreak {
                numberCell($draft.modes[safeIndex].rows[i].dmxBreak, original.dmxBreak, 1...64, W.small + 14, placeholder: "1")
            } else {
                unsupported(W.small + 14)
            }
            numberCell($draft.modes[safeIndex].rows[i].coarse, original.coarse, 1...512, W.small)
            numberCell($draft.modes[safeIndex].rows[i].fine, original.fine, 1...512, W.small)
            numberCell($draft.modes[safeIndex].rows[i].ultra, original.ultra, 1...512, W.small)
            numberCell($draft.modes[safeIndex].rows[i].defaultValue, original.defaultValue, 0...255, W.value, placeholder: "None")
            numberCell($draft.modes[safeIndex].rows[i].highlight, original.highlight, 0...255, W.value + 8, placeholder: "None")
            if caps.hasLowlight {
                numberCell($draft.modes[safeIndex].rows[i].lowlight, original.lowlight, 0...255, W.value + 6, placeholder: "None")
            } else {
                unsupported(W.value + 6)
            }
            Toggle("", isOn: $draft.modes[safeIndex].rows[i].snap)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: W.snap)
        }
        .padding(.vertical, 3)
        .background(bad == nil ? Color.clear : Color.red.opacity(0.15))
        .help(bad ?? "")
    }

    private func unsupported(_ width: CGFloat) -> some View {
        Text("—").foregroundStyle(.tertiary).frame(width: width)
    }

    /// A number cell: empty = None, digits only, clamped to `range`; tinted
    /// when it differs from the file's current value.
    private func numberCell(_ value: Binding<Int?>, _ original: Int?, _ range: ClosedRange<Int>,
                            _ width: CGFloat, placeholder: String = "") -> some View {
        let text = Binding<String>(
            get: { value.wrappedValue.map(String.init) ?? "" },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                if digits.isEmpty { value.wrappedValue = nil }
                else if let n = Int(digits) { value.wrappedValue = min(max(n, range.lowerBound), range.upperBound) }
            }
        )
        return TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.callout.monospacedDigit())
            .padding(.vertical, 3)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(value.wrappedValue != original ? Color.orange.opacity(0.28) : Color.secondary.opacity(0.10))
            )
    }

    /// Logical channel -> channel function -> channel set detail (read-only).
    private func functionsView(_ row: DMXChannelRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(row.functions.enumerated()), id: \.offset) { _, f in
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.down.right").font(.caption2).foregroundStyle(.tertiary)
                    Text(f.name.isEmpty ? f.attribute : f.name).frame(minWidth: 120, alignment: .leading)
                    if !f.dmxFrom.isEmpty { Text("DMX \(f.dmxFrom)").foregroundStyle(.secondary) }
                    if !f.defaultValue.isEmpty { Text("Default \(f.defaultValue)").foregroundStyle(.secondary) }
                    if !f.physical.isEmpty { Text(f.physical).foregroundStyle(.secondary) }
                    if f.setCount > 0 { Text("セット \(f.setCount)").foregroundStyle(.secondary) }
                }
                .font(.caption)
            }
        }
        .padding(.leading, W.expander + W.number + 12)
        .padding(.vertical, 4)
    }
}
