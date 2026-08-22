import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileListView: View {
    @Environment(SourceStore.self) private var store
    @Environment(TransferState.self) private var transferState
    let source: any FileSource
    let category: ConsoleCategory
    @Binding var currentPath: RelativePath

    @State private var entries: [FileEntry] = []
    @State private var searchText = ""
    @State private var selectedManufacturer: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isDropTargeted = false
    @State private var selection: Set<String> = []
    @State private var isSelectionMode = false
    @State private var renamingEntry: FileEntry?
    @State private var renameBaseName = ""
    @State private var renameExtension = ""
    @State private var renameError: String?
    @State private var pendingDelete: DeleteTarget?
    @State private var deleteError: String?

    private enum DeleteTarget: Identifiable {
        case single(FileEntry)
        case bulk([FileEntry])

        var id: String {
            switch self {
            case .single(let entry): return entry.id
            case .bulk: return "bulk"
            }
        }

        var entries: [FileEntry] {
            switch self {
            case .single(let entry): return [entry]
            case .bulk(let entries): return entries
            }
        }
    }

    /// Many fixture library entries are named "<Manufacturer>@<Model>@<date/release>"
    /// (e.g. "Elation@Fuze_Wash_Z120@2023-15-05_First_Release"). When a
    /// folder's contents follow that convention, offer a manufacturer
    /// picker instead of making the user scroll/search through hundreds of
    /// entries — extracted straight from the "@"-delimited names, not tied
    /// to any specific category, since this convention shows up wherever
    /// the fixture library data lives.
    private var availableManufacturers: [String] {
        let names = entries.compactMap { entry -> String? in
            guard let atIndex = entry.name.firstIndex(of: "@") else { return nil }
            return String(entry.name[entry.name.startIndex..<atIndex])
        }
        guard names.count >= entries.count / 2, !names.isEmpty else { return [] }
        return Array(Set(names)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var filteredEntries: [FileEntry] {
        var result = entries
        if let selectedManufacturer {
            result = result.filter { $0.name.hasPrefix("\(selectedManufacturer)@") }
        }
        guard !searchText.isEmpty else { return result }
        return result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var breadcrumbSuffix: [String] {
        let base = source.categoryPath(for: category).components
        guard currentPath.components.count >= base.count,
              Array(currentPath.components.prefix(base.count)) == base else {
            return []
        }
        return Array(currentPath.components.suffix(from: base.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            Divider()
            searchBar
            if source.supportsDestructiveOperations && isSelectionMode {
                Divider()
                selectionBar
            }
            Divider()
            content
                .overlay(dropOverlay)
                .onDrop(of: [.fileURL, .ma3InternalFileRef], isTargeted: $isDropTargeted) { providers in
                    loadDropPayloads(from: providers) { payloads in
                        Task {
                            await handleDrop(payloads, into: source, at: currentPath, store: store, transferState: transferState)
                            await reload()
                        }
                    }
                    return true
                }
        }
        .task(id: currentPath) {
            selection = []
            isSelectionMode = false
            selectedManufacturer = nil
            await reload()
        }
        .alert("名前を変更", isPresented: Binding(
            get: { renamingEntry != nil },
            set: { if !$0 { renamingEntry = nil } }
        )) {
            TextField("名前", text: $renameBaseName)
            Button("変更") { commitRename() }
            Button("キャンセル", role: .cancel) { renamingEntry = nil }
        }
        .alert("リネームエラー", isPresented: Binding(
            get: { renameError != nil },
            set: { if !$0 { renameError = nil } }
        )) {
            Button("OK") { renameError = nil }
        } message: {
            Text(renameError ?? "")
        }
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) { commitDelete() }
            Button("キャンセル", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("この操作は取り消せません。本当によろしいですか？(Finderのゴミ箱には入ります)")
        }
        .alert("削除エラー", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var deleteConfirmTitle: String {
        guard let pendingDelete else { return "" }
        switch pendingDelete {
        case .single(let entry):
            return "「\(entry.name)」を本当に削除しますか？"
        case .bulk(let entries):
            return "選択した\(entries.count)件を本当に削除しますか？"
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 4) {
            Button {
                currentPath = source.categoryPath(for: category)
            } label: {
                Label(category.displayName, systemImage: category.symbolName)
            }
            .buttonStyle(.plain)

            ForEach(Array(breadcrumbSuffix.enumerated()), id: \.offset) { index, component in
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                Button(component) {
                    let base = source.categoryPath(for: category).components
                    currentPath = RelativePath(components: base + Array(breadcrumbSuffix.prefix(index + 1)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if source.supportsDestructiveOperations {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSelectionMode.toggle()
                        if !isSelectionMode { selection = [] }
                    }
                } label: {
                    Label(isSelectionMode ? "選択を終了" : "選択", systemImage: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelectionMode ? Color.accentColor : .primary)
            }
            Button {
                Task { await reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("このフォルダ内を検索", text: $searchText)
                .textFieldStyle(.plain)
            if !availableManufacturers.isEmpty {
                Picker("メーカー", selection: $selectedManufacturer) {
                    Text("すべてのメーカー").tag(String?.none)
                    Divider()
                    ForEach(availableManufacturers, id: \.self) { manufacturer in
                        Text(manufacturer).tag(String?.some(manufacturer))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var selectionBar: some View {
        HStack {
            Text(selection.isEmpty ? "選択モード: 項目をタップして選択" : "\(selection.count)件を選択中")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("すべて選択") {
                selection = Set(filteredEntries.map(\.id))
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                let targets = entries.filter { selection.contains($0.id) }
                pendingDelete = .bulk(targets)
            } label: {
                Label("削除...", systemImage: "trash")
            }
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .transition(.opacity)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                Text(errorMessage).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredEntries.isEmpty {
            Text("ファイルがありません")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredEntries, selection: $selection) { entry in
                FileRowView(
                    entry: entry,
                    isSelectionMode: isSelectionMode,
                    isChecked: selection.contains(entry.id),
                    onToggleCheck: { toggleSelection(entry) }
                )
                    .contentShape(Rectangle())
                    .onTapGesture(count: isSelectionMode ? 1 : 2) {
                        if isSelectionMode {
                            toggleSelection(entry)
                        } else {
                            handleOpen(entry)
                        }
                    }
                    .contextMenu {
                        if entry.isDirectory {
                            Button("開く") { handleOpen(entry) }
                        } else {
                            Button("Finderで表示...") { revealAfterCopy(entry) }
                        }
                        if source.supportsDestructiveOperations {
                            Divider()
                            Button("名前を変更...") { beginRename(entry) }
                            Button("削除...", role: .destructive) { pendingDelete = .single(entry) }
                        }
                    }
                    .onDrag {
                        makeDragProvider(sourceID: source.id, path: entry.path, localURL: source.localFileURL(for: entry.path))
                    }
            }
            .listStyle(.inset)
        }
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 3 : 0)
            .padding(4)
            .allowsHitTesting(false)
    }

    private func toggleSelection(_ entry: FileEntry) {
        if selection.contains(entry.id) {
            selection.remove(entry.id)
        } else {
            selection.insert(entry.id)
        }
    }

    private func handleOpen(_ entry: FileEntry) {
        if entry.isDirectory {
            currentPath = entry.path
        } else {
            try? source.reveal(entry.path)
        }
    }

    private func revealAfterCopy(_ entry: FileEntry) {
        try? source.reveal(entry.path)
    }

    private func beginRename(_ entry: FileEntry) {
        if entry.isDirectory {
            // Directories have no extension to protect; a dot in a folder
            // name (e.g. "v2.4 backups") isn't a file extension.
            renameBaseName = entry.name
            renameExtension = ""
        } else {
            let nsName = entry.name as NSString
            let ext = nsName.pathExtension
            renameExtension = ext
            renameBaseName = ext.isEmpty ? entry.name : nsName.deletingPathExtension
        }
        renamingEntry = entry
    }

    private func commitRename() {
        defer { renamingEntry = nil }
        guard let entry = renamingEntry, !renameBaseName.isEmpty else { return }
        let newName = renameExtension.isEmpty ? renameBaseName : "\(renameBaseName).\(renameExtension)"
        guard newName != entry.name else { return }
        Task {
            do {
                try await source.rename(entry.path, to: newName)
                await reload()
            } catch {
                renameError = error.localizedDescription
            }
        }
    }

    private func commitDelete() {
        guard let pendingDelete else { return }
        let targets = pendingDelete.entries
        self.pendingDelete = nil
        Task {
            for entry in targets {
                do {
                    try await source.delete(entry.path)
                } catch {
                    deleteError = error.localizedDescription
                }
            }
            selection = []
            await reload()
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await source.list(currentPath)
        } catch {
            entries = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
