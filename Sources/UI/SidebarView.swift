import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(SourceStore.self) private var store
    @Binding var selectedSourceID: UUID?
    /// Origin source of whatever's currently being browsed/dragged, and the
    /// category it belongs to — used so dropping a file onto another Source
    /// in the sidebar imports it into that *same category* on the target,
    /// e.g. dragging a show from USB's "Shows" list onto "onPC" lands it in
    /// onPC's Shows folder, no manual navigation needed.
    let activeCategory: ConsoleCategory?
    var onDropOnSource: (UUID, [DropPayload]) -> Void

    @State private var showingAddSheet = false
    @State private var renamingConfig: SourceConfig?
    @State private var renameText = ""
    @State private var editingSFTPConfig: SourceConfig?

    var body: some View {
        List(selection: $selectedSourceID) {
            Section("Sources") {
                ForEach(store.configs) { config in
                    SourceRow(
                        config: config,
                        activeCategory: activeCategory,
                        isDropDisabled: config.id == selectedSourceID,
                        onDrop: { payloads in onDropOnSource(config.id, payloads) }
                    )
                    .tag(config.id)
                    .contextMenu {
                        Button("名前を変更...") {
                            renameText = config.name
                            renamingConfig = config
                        }
                        if config.kind == .sftp {
                            Button("接続設定を編集...") {
                                editingSFTPConfig = config
                            }
                        }
                        Button("削除", role: .destructive) {
                            store.removeSource(id: config.id)
                        }
                    }
                }
            }
        }
        .sheet(item: $editingSFTPConfig) { config in
            EditSFTPSourceSheet(existingConfig: config)
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Sourceを追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSourceSheet()
        }
        .alert("名前を変更", isPresented: Binding(
            get: { renamingConfig != nil },
            set: { if !$0 { renamingConfig = nil } }
        )) {
            TextField("名前", text: $renameText)
            Button("変更") {
                if let config = renamingConfig {
                    store.renameSource(id: config.id, to: renameText)
                }
                renamingConfig = nil
            }
            Button("キャンセル", role: .cancel) { renamingConfig = nil }
        }
    }
}

private struct SourceRow: View {
    @Environment(SourceStore.self) private var store
    let config: SourceConfig
    let activeCategory: ConsoleCategory?
    let isDropDisabled: Bool
    var onDrop: ([DropPayload]) -> Void

    @State private var isTargeted = false

    private var isConnected: Bool {
        store.source(for: config.id)?.connectionState == .connected
    }

    /// True if this SFTP console's host shares a subnet with one of this
    /// Mac's own network interfaces — i.e. it's reachable on the same LAN
    /// segment (whatever's plugged into the Manet adapter), not routed.
    private var isSameMANet: Bool {
        guard config.kind == .sftp, let host = config.host else { return false }
        return NetworkInterfaceHelper.isHostOnLocalSubnet(host)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Label(config.name, systemImage: config.kind.symbolName)
                Text(config.resolvedFamily.shortLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.18))
                    .clipShape(Capsule())
                if config.kind == .sftp {
                    Spacer()
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                        .help(isConnected ? "接続済み" : "未接続")
                }
            }
            if isSameMANet, let host = config.host {
                HStack(spacing: 4) {
                    Text("MA Net")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                    Text(host)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                isTargeted
                    ? Color.accentColor.opacity(0.35)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSameMANet ? Color.orange : Color.clear, lineWidth: 1.5)
            )
            .help(activeCategory == nil
                  ? "先にカテゴリを選択すると、ここへドロップしてこのSourceの同じカテゴリへコピーできます"
                  : "ドロップすると「\(activeCategory!.displayName)」に追加されます")
            .onDrop(of: [.fileURL, .ma3InternalFileRef], isTargeted: isDropDisabled ? nil : $isTargeted) { providers in
                guard !isDropDisabled, activeCategory != nil else { return false }
                loadDropPayloads(from: providers, completion: onDrop)
                return true
            }
    }
}
