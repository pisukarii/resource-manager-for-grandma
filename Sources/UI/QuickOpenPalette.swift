import SwiftUI

struct QuickOpenPalette: View {
    @Environment(SourceStore.self) private var store
    @Environment(FileIndex.self) private var index
    @Environment(\.dismiss) private var dismiss

    /// Jumps the main window to the selected entry's source/category/folder.
    var onSelect: (IndexedEntry) -> Void

    @State private var query = ""
    @FocusState private var isFieldFocused: Bool

    private var results: [IndexedEntry] {
        index.search(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("ファイル名で検索 (全Source横断)", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                if index.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)

            Divider()

            if query.isEmpty {
                VStack(spacing: 6) {
                    Text("入力してファイルを検索")
                        .foregroundStyle(.secondary)
                    if let last = index.lastRefreshed {
                        Text("最終インデックス更新: \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                Text("一致するファイルがありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { indexed in
                    Button {
                        onSelect(indexed)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: indexed.entry.isDirectory ? "folder.fill" : "doc")
                                .foregroundStyle(indexed.entry.isDirectory ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(indexed.entry.name)
                                Text("\(indexed.sourceName) / \(indexed.category.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 520, height: 360)
        .task {
            isFieldFocused = true
            await index.refresh(sources: store.sources)
        }
    }
}
