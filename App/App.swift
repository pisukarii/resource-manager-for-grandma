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
            CommandGroup(after: .toolbar) {
                Button("Quick Open...") {
                    uiState.isQuickOpenPresented = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
