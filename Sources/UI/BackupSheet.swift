import SwiftUI
import AppKit

/// 右クリック > USBにバックアップ: pick the USB, pick what to back up, then
/// watch the progress. Writes `<USB>/YYMMDD-MAbackup/` holding the MA files
/// as they are (library-type data only — no app files).
struct BackupSheet: View {
    let config: SourceConfig
    /// For previews/tests only: show these instead of the mounted volumes.
    var overrideVolumes: [ExternalVolume]? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var volumes: [ExternalVolume] = []
    @State private var selectedVolumeID: String?
    @State private var scope: BackupScope = .library
    @State private var job = BackupJob()
    @State private var estimate: Estimate = .calculating
    @State private var mountObservers: [NSObjectProtocol] = []

    private enum Estimate: Equatable {
        case calculating
        case ready(files: Int, bytes: Int64)
    }

    private var plan: BackupPlan { BackupPlan.make(for: config, scope: scope) }
    private var selectedVolume: ExternalVolume? { volumes.first { $0.id == selectedVolumeID } }

    private var previewFolder: String {
        guard let volume = selectedVolume else { return BackupEngine.baseFolderName() }
        return BackupEngine.folderName(in: volume.url)
    }

    private var notEnoughSpace: Bool {
        guard let free = selectedVolume?.freeBytes, case .ready(_, let bytes) = estimate else { return false }
        return bytes > free
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("USBにバックアップ").font(.title3.bold())
            switch job.phase {
            case .idle:
                setup
            case .scanning, .copying:
                running
            case .finished(let files, let bytes):
                finished(files: files, bytes: bytes)
            case .cancelled:
                result(icon: "xmark.circle.fill", color: .secondary,
                       title: "バックアップを中止しました",
                       detail: "途中までコピーしたフォルダは削除しました。")
            case .failed(let message):
                result(icon: "exclamationmark.triangle.fill", color: .red,
                       title: "バックアップできませんでした", detail: message)
            }
        }
        .padding(20)
        .frame(width: 540)
        .onAppear { reloadVolumes(); observeMounts() }
        .onDisappear { mountObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }; mountObservers = [] }
        .task(id: scope) { await computeEstimate() }
        .interactiveDismissDisabled(job.isRunning)
    }

    // MARK: Setup

    private var setup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("「\(config.name)」のデータを、USBメモリの中の「\(previewFolder)」フォルダにコピーします。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("どのUSBにバックアップしますか？").font(.headline)
                if volumes.isEmpty {
                    HStack {
                        Image(systemName: "externaldrive.badge.questionmark").foregroundStyle(.secondary)
                        Text("USBメモリが見つかりません。差し込むと自動で一覧に出ます。")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button("再読み込み") { reloadVolumes() }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 6) {
                        ForEach(volumes) { volume in volumeRow(volume) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("バックアップする内容").font(.headline)
                Picker("", selection: $scope) {
                    Text("ライブラリ一式").tag(BackupScope.library)
                    Text("ショーファイルのみ").tag(BackupScope.showsOnly)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 3) {
                    if plan.isEmpty {
                        ForEach(plan.notes, id: \.self) { note in
                            Label(note, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    } else {
                        ForEach(plan.items, id: \.self) { item in
                            Label(item.title, systemImage: "folder").foregroundStyle(.secondary)
                        }
                        Text(scope == .library
                             ? "アプリ本体(onpc / systemapp / ma / language など)は含みません。MAのファイルはそのままの形式・フォルダ構成でコピーします。"
                             : "ショーファイルだけを、MAのフォルダ構成のままコピーします。")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .font(.caption)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    switch estimate {
                    case .calculating:
                        ProgressView().controlSize(.small)
                        Text("容量を計算中...").foregroundStyle(.secondary)
                    case .ready(let files, let bytes):
                        Text("コピー対象: \(files.formatted())ファイル / \(BackupJob.size(bytes))")
                            .foregroundStyle(notEnoughSpace ? Color.red : .secondary)
                        if notEnoughSpace {
                            Text("— USBの空き容量が足りません").foregroundStyle(.red)
                        }
                    }
                }
                .font(.caption)
            }

            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("バックアップを開始") {
                    if let volume = selectedVolume { job.start(plan: plan, volume: volume) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedVolume == nil || plan.isEmpty || notEnoughSpace || estimate == .calculating)
            }
        }
    }

    private func volumeRow(_ volume: ExternalVolume) -> some View {
        let selected = selectedVolumeID == volume.id
        return Button {
            selectedVolumeID = volume.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Image(systemName: "externaldrive")
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(volume.name)
                        if volume.hasMAFolder {
                            Text("MAのUSB")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.2)).clipShape(Capsule())
                        }
                    }
                    if let total = volume.totalBytes, let free = volume.freeBytes {
                        Text("空き \(BackupJob.size(free)) / 全体 \(BackupJob.size(total))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Running / finished

    private var running: some View {
        let p = job.progress
        let fraction = p.totalBytes > 0 ? Double(p.doneBytes) / Double(p.totalBytes) : 0
        return VStack(alignment: .leading, spacing: 10) {
            if job.phase == .scanning {
                HStack { ProgressView().controlSize(.small); Text("コピーするファイルを調べています...") }
            } else {
                Text("「\(job.folderURL?.lastPathComponent ?? "")」にコピー中...").font(.callout)
                ProgressView(value: fraction)
                HStack {
                    Text("\(Int(fraction * 100))%").monospacedDigit()
                    Text("\(BackupJob.size(p.doneBytes)) / \(BackupJob.size(p.totalBytes))").foregroundStyle(.secondary)
                    Spacer()
                    Text("ファイル \(p.doneFiles.formatted()) / \(p.totalFiles.formatted())").foregroundStyle(.secondary)
                }
                .font(.callout)
                Text(p.currentFile)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Text("USBを抜かないでください。")
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("中止") { job.cancel() }
            }
        }
    }

    private func finished(files: Int, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("バックアップが完了しました", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
            Text("\(files.formatted())ファイル / \(BackupJob.size(bytes)) を コピーしました。")
            if let folder = job.folderURL {
                Text(folder.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
            if !job.unreadable.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Label("\(job.unreadable.count)件のファイルは読み込めず、コピーされていません", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    ForEach(job.unreadable.prefix(5), id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                    if job.unreadable.count > 5 { Text("ほか \(job.unreadable.count - 5)件").font(.caption2).foregroundStyle(.secondary) }
                }
                .font(.callout)
            }
            HStack {
                Button("Finderで表示") {
                    if let folder = job.folderURL { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                }
                if let volume = selectedVolume {
                    Button("USBを取り出す") {
                        try? NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
                        dismiss()
                    }
                }
                Spacer()
                Button("閉じる") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func result(icon: String, color: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
            Text(detail).font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("閉じる") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: Helpers

    private func reloadVolumes() {
        volumes = overrideVolumes ?? ExternalVolume.list(excludingContaining: config.path)
        if selectedVolumeID == nil || !volumes.contains(where: { $0.id == selectedVolumeID }) {
            // One USB: just pick it. With several, make the user choose.
            selectedVolumeID = volumes.count == 1 ? volumes.first?.id : nil
        }
    }

    private func observeMounts() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            mountObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in reloadVolumes() }
            })
        }
    }

    private func computeEstimate() async {
        estimate = .calculating
        let items = plan.items
        let result: Estimate = await Task.detached(priority: .utility) {
            let scan = BackupEngine.scan(items)
            return .ready(files: scan.files.count, bytes: scan.totalBytes)
        }.value
        estimate = result
    }
}
