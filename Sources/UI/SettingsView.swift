import SwiftUI

/// 設定 (⌘,): choose which library categories show up. A checked item is
/// shown in the category list; unchecked items are hidden.
struct SettingsView: View {
    private let settings = CategorySettings.shared

    private var ma3: [ConsoleCategory] { ConsoleFamily.ma3.categories }
    private var ma2: [ConsoleCategory] { ConsoleFamily.ma2.categories }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("表示するカテゴリ").font(.title3.bold())
                Text("チェックを付けた項目だけが、左のカテゴリ一覧とクイックオープンの検索に表示されます。フォルダやファイル自体は変更されません。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Form {
                section("grandMA3 — バージョンごと (Shows / Backups など)",
                        ma3.filter { $0.rootKind == .versionScoped })
                section("grandMA3 — 共有ライブラリ (gma3_library)",
                        ma3.filter { $0.rootKind == .library })
                section("grandMA2", ma2)
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("すべて表示") { settings.setAllVisible(true, in: ma3 + ma2) }
                Button("すべて非表示") { settings.setAllVisible(false, in: ma3 + ma2) }
                Spacer()
                Text("\(hiddenCount)件を非表示中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(width: 480, height: 600)
    }

    private var hiddenCount: Int {
        (ma3 + ma2).filter { !settings.isVisible($0) }.count
    }

    private func section(_ title: String, _ categories: [ConsoleCategory]) -> some View {
        Section {
            ForEach(categories) { category in
                Toggle(isOn: Binding(
                    get: { settings.isVisible(category) },
                    set: { settings.setVisible($0, for: category) }
                )) {
                    Label(category.displayName, systemImage: category.symbolName)
                }
                .toggleStyle(.checkbox)
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Button("すべて表示") { settings.setAllVisible(true, in: categories) }
                Button("すべて非表示") { settings.setAllVisible(false, in: categories) }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }
}
