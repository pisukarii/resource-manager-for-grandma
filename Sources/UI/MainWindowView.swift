import SwiftUI

struct MainWindowView: View {
    @Environment(SourceStore.self) private var store
    @Environment(USBVolumeWatcher.self) private var usbWatcher
    @Environment(AppUIState.self) private var uiState
    @Environment(TransferState.self) private var transferState
    @State private var selectedSourceID: UUID?
    @State private var selectedCategory: ConsoleCategory?
    @State private var currentPath: RelativePath = .root
    @State private var connectionError: String?

    private var selectedSource: (any FileSource)? {
        guard let selectedSourceID else { return nil }
        return store.source(for: selectedSourceID)
    }

    /// Wraps `selectedSourceID` so switching Source in the sidebar also
    /// re-resolves `currentPath` against the newly selected source, without
    /// relying on `.onChange` ordering across multiple state variables.
    private var sourceSelectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedSourceID },
            set: { newID in
                selectedSourceID = newID
                guard let newID, let source = store.source(for: newID) else { return }
                if let category = selectedCategory {
                    currentPath = source.categoryPath(for: category)
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pendingDetection = usbWatcher.pendingDetection {
                USBDetectionBanner(detection: pendingDetection)
                Divider()
            }
            mainSplitView
            if transferState.isActive {
                transferProgressBar
            }
        }
        .alert("転送エラー", isPresented: Binding(
            get: { transferState.errorMessage != nil },
            set: { if !$0 { transferState.errorMessage = nil } }
        )) {
            Button("OK") { transferState.errorMessage = nil }
        } message: {
            Text(transferState.errorMessage ?? "")
        }
        .onAppear {
            if selectedSourceID == nil {
                selectedSourceID = store.configs.first?.id
            }
        }
        .sheet(isPresented: Binding(
            get: { uiState.isQuickOpenPresented },
            set: { uiState.isQuickOpenPresented = $0 }
        )) {
            QuickOpenPalette(onSelect: jumpTo)
        }
    }

    private var transferProgressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transferState.label)
                .font(.caption)
                .lineLimit(1)
            ProgressView(value: transferState.progress)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: transferState.isActive)
    }

    private var mainSplitView: some View {
        NavigationSplitView {
            SidebarView(
                selectedSourceID: sourceSelectionBinding,
                activeCategory: selectedCategory,
                onDropOnSource: importToOtherSource
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
        } detail: {
            if store.configs.isEmpty {
                FirstRunWelcomeView()
            } else if let source = selectedSource {
                HStack(spacing: 0) {
                    CategoryShortcutBar(source: source, selectedCategory: selectedCategory, onSelect: selectCategory) { category, payloads in
                        Task {
                            await handleDrop(payloads, into: source, at: source.categoryPath(for: category), store: store, transferState: transferState)
                        }
                    }
                    Divider()
                    if let category = selectedCategory {
                        FileListView(source: source, category: category, currentPath: $currentPath)
                            .id(source.id)
                    } else {
                        Text("左のカテゴリを選択してください")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .task(id: source.id) {
                    await connect(source)
                }
                .alert("接続エラー", isPresented: Binding(
                    get: { connectionError != nil },
                    set: { if !$0 { connectionError = nil } }
                )) {
                    Button("OK") { connectionError = nil }
                } message: {
                    Text(connectionError ?? "")
                }
            } else {
                Text("左のリストから Source を選択してください")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    uiState.isQuickOpenPresented = true
                } label: {
                    Label("Quick Open (⌘K)", systemImage: "magnifyingglass")
                }
                .help("すべてのSourceを横断してファイル名で検索 (⌘K)")
            }
        }
    }

    private func selectCategory(_ category: ConsoleCategory) {
        selectedCategory = category
        if let source = selectedSource {
            currentPath = source.categoryPath(for: category)
        }
    }

    /// Handles a drop onto a Source in the sidebar: imports into that
    /// Source's version of the category currently being browsed, so
    /// dragging a show from USB's "Shows" list onto "onPC" in the sidebar
    /// lands it straight in onPC's Shows folder — including when the drag
    /// originated on another SFTP console, via the internal-ref transfer.
    private func importToOtherSource(targetSourceID: UUID, payloads: [DropPayload]) {
        guard let category = selectedCategory, let target = store.source(for: targetSourceID) else { return }
        Task {
            await handleDrop(payloads, into: target, at: target.categoryPath(for: category), store: store, transferState: transferState)
        }
    }

    private func jumpTo(_ indexed: IndexedEntry) {
        selectedSourceID = indexed.sourceID
        selectedCategory = indexed.category
        if let source = store.source(for: indexed.sourceID) {
            currentPath = indexed.entry.isDirectory ? indexed.entry.path : source.categoryPath(for: indexed.category)
        }
    }

    private func connect(_ source: any FileSource) async {
        do {
            try await source.connect()
        } catch {
            connectionError = error.localizedDescription
        }
    }
}
