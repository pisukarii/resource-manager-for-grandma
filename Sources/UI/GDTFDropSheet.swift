import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Shown right after a GDTF Share search is opened: says where the file
/// will go, and gives a drop area for the downloaded .gdtf.
struct GDTFDropRequest: Identifiable {
    let id = UUID()
    let fileName: String      // the .pxml the search was for
    let words: String
}

struct GDTFDropSheet: View {
    let request: GDTFDropRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(AppUIState.self) private var uiState

    private struct Line: Identifiable {
        let id = UUID()
        let text: String
        let kind: Kind
        enum Kind { case ok, info, error }
    }

    @State private var isTargeted = false
    @State private var lines: [Line] = []
    @State private var isWorking = false

    private var destinationPath: String {
        (GDTFLibrary.destinationFolder.path as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GDTFを追加").font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                step(1, "ブラウザで GDTF Share の「\(request.words)」の検索結果を開きました(ログインが必要です)。")
                step(2, "使いたいGDTFをダウンロードします。")
                step(3, "ダウンロードした .gdtf ファイルを、下のエリアにドラッグ&ドロップします。")
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("保存先", systemImage: "folder").font(.callout.weight(.semibold))
                Text(destinationPath)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                Text("grandMA3のユーザーライブラリです。MA3の Patch → Fixture Types → Import でここから選べます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            dropArea

            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines) { line in
                        Label(line.text, systemImage: icon(for: line.kind))
                            .font(.callout)
                            .foregroundStyle(color(for: line.kind))
                    }
                }
            }

            HStack {
                Button("ダウンロードフォルダを開く") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Downloads", isDirectory: true))
                }
                Button("保存先をFinderで表示") {
                    try? FileManager.default.createDirectory(at: GDTFLibrary.destinationFolder, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(GDTFLibrary.destinationFolder)
                }
                Spacer()
                Button("閉じる") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private var dropArea: some View {
        VStack(spacing: 8) {
            Image(systemName: isWorking ? "hourglass" : "square.and.arrow.down.on.square")
                .font(.system(size: 30))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("ここに .gdtf ファイルをドロップ")
                .font(.headline)
            Button("ファイルを選ぶ...") { chooseFiles() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5),
                              style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in await add([url]) }
                }
            }
            return !providers.isEmpty
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor.opacity(0.25)))
            Text(text).font(.callout)
        }
    }

    private func icon(for kind: Line.Kind) -> String {
        switch kind {
        case .ok: return "checkmark.circle.fill"
        case .info: return "minus.circle"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for kind: Line.Kind) -> Color {
        switch kind {
        case .ok: return .green
        case .info: return .secondary
        case .error: return .red
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if let type = UTType(filenameExtension: "gdtf") { panel.allowedContentTypes = [type] }
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        panel.prompt = "追加"
        guard panel.runModal() == .OK else { return }
        Task { await add(panel.urls) }
    }

    private func add(_ urls: [URL]) async {
        isWorking = true
        defer { isWorking = false }
        for url in urls {
            switch await GDTFLibrary.add(url) {
            case .added(let added):
                lines.append(Line(text: "追加しました: \(added.fixture)(\(added.fileName))", kind: .ok))
                uiState.refreshTick += 1   // so an open library folder shows the new file
            case .skipped(let name):
                lines.append(Line(text: "「\(name)」はキャンセルしました(上書きしませんでした)。", kind: .info))
            case .failed(let message):
                lines.append(Line(text: message, kind: .error))
            }
        }
    }
}
