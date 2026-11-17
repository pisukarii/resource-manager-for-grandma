import SwiftUI

@main
struct GrandMAResourceManagerApp: App {
    @State private var store = SourceStore()
    @State private var usbWatcher: USBVolumeWatcher
    @State private var fileIndex = FileIndex()
    @State private var uiState = AppUIState()
    @State private var transferState = TransferState()

    init() {
        let store = SourceStore()
        _store = State(initialValue: store)
        _usbWatcher = State(initialValue: USBVolumeWatcher(store: store))
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(store)
                .environment(usbWatcher)
                .environment(fileIndex)
                .environment(uiState)
                .environment(transferState)
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowResizability(.contentSize)
        .commands {
            // File menu: this app is one window with Sources, so "新規ウインドウ"
            // is replaced by the thing people actually add here.
            CommandGroup(replacing: .newItem) {
                Button("Sourceを追加...") {
                    uiState.isAddSourcePresented = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            // View menu.
            CommandGroup(before: .toolbar) {
                Button("クイックオープン...") {
                    uiState.isQuickOpenPresented = true
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("一覧を更新") {
                    uiState.refreshTick += 1
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
            }
            // Help menu: the stock "ヘルプ" search has nothing to show for this app.
            CommandGroup(replacing: .help) {
                Link("使い方・最新版(GitHub)", destination: URL(string: "https://github.com/pisukarii/resource-manager-for-grandma")!)
                Link("不具合の報告・要望", destination: URL(string: "https://github.com/pisukarii/resource-manager-for-grandma/issues")!)
            }
        }

        // 設定 (⌘,) — which library categories to show.
        Settings {
            SettingsView()
        }
    }
}
