import SwiftUI
import UniformTypeIdentifiers

struct CategoryShortcutBar: View {
    let source: any FileSource
    let selectedCategory: ConsoleCategory?
    var onSelect: (ConsoleCategory) -> Void
    var onDrop: (ConsoleCategory, [DropPayload]) -> Void

    private var hiddenCount: Int {
        source.config.visibleCategories.filter { !CategorySettings.shared.isVisible($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(source.config.visibleCategories.filter { CategorySettings.shared.isVisible($0) }) { category in
                        CategoryRow(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            onSelect: { onSelect(category) },
                            onDrop: { payloads in onDrop(category, payloads) }
                        )
                        .contextMenu {
                            Button("「\(category.displayName)」を非表示") {
                                CategorySettings.shared.setVisible(false, for: category)
                            }
                            Divider()
                            SettingsLink {
                                Label("表示するカテゴリを設定...", systemImage: "checklist")
                            }
                        }
                    }
                }
                .padding(8)
            }
            Divider()
            // Pick which categories show here (checked = shown); also in 設定 (⌘,).
            SettingsLink {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                    Text("表示項目を選ぶ")
                    Spacer()
                    if hiddenCount > 0 {
                        Text("\(hiddenCount)件非表示")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("左の一覧に表示するカテゴリを、チェックで選べます(⌘,)")
        }
        .frame(width: 190)
        .background(.thinMaterial)
    }
}

private struct CategoryRow: View {
    let category: ConsoleCategory
    let isSelected: Bool
    let onSelect: () -> Void
    let onDrop: ([DropPayload]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: category.symbolName)
                    .frame(width: 20)
                Text(category.displayName)
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                isTargeted
                    ? Color.accentColor.opacity(0.35)
                    : (isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL, .ma3InternalFileRef], isTargeted: $isTargeted) { providers in
            loadDropPayloads(from: providers, completion: onDrop)
            return true
        }
    }
}
