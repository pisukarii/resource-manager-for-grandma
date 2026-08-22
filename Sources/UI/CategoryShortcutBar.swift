import SwiftUI
import UniformTypeIdentifiers

struct CategoryShortcutBar: View {
    let source: any FileSource
    let selectedCategory: ConsoleCategory?
    var onSelect: (ConsoleCategory) -> Void
    var onDrop: (ConsoleCategory, [DropPayload]) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(source.config.resolvedFamily.categories) { category in
                    CategoryRow(
                        category: category,
                        isSelected: selectedCategory?.id == category.id,
                        onSelect: { onSelect(category) },
                        onDrop: { payloads in onDrop(category, payloads) }
                    )
                }
            }
            .padding(8)
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
