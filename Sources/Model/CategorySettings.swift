import Foundation
import Observation

/// Which library categories the user has chosen to hide (設定 > ライブラリ).
/// Hidden categories disappear from the category sidebar and from Quick
/// Open's search index; the files themselves are untouched. Stored in
/// UserDefaults so it survives relaunch.
@MainActor
@Observable
final class CategorySettings {
    static let shared = CategorySettings()

    private static let defaultsKey = "hiddenCategoryIDs"

    private(set) var hiddenIDs: Set<String>

    private init() {
        hiddenIDs = Set(UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? [])
    }

    func isVisible(_ category: ConsoleCategory) -> Bool {
        !hiddenIDs.contains(category.id)
    }

    func setVisible(_ visible: Bool, for category: ConsoleCategory) {
        if visible { hiddenIDs.remove(category.id) } else { hiddenIDs.insert(category.id) }
        save()
    }

    func setAllVisible(_ visible: Bool, in categories: [ConsoleCategory]) {
        for category in categories {
            if visible { hiddenIDs.remove(category.id) } else { hiddenIDs.insert(category.id) }
        }
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(hiddenIDs).sorted(), forKey: Self.defaultsKey)
    }
}
