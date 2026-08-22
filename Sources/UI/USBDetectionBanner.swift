import SwiftUI

struct USBDetectionBanner: View {
    @Environment(SourceStore.self) private var store
    @Environment(USBVolumeWatcher.self) private var watcher
    let detection: DetectedUSBSource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .foregroundStyle(.blue)
            Text("\(detection.family.displayName) USBメモリ「\(detection.volumeURL.lastPathComponent)」を検出しました")
            Spacer()
            Button("Sourceとして追加") {
                let bookmark = BookmarkStore.makeBookmark(for: detection.dataRootURL)
                let config = SourceConfig(
                    name: detection.volumeURL.lastPathComponent,
                    kind: .usb,
                    path: detection.dataRootURL.path,
                    bookmarkData: bookmark,
                    family: detection.family
                )
                store.addSource(config)
                watcher.dismissPending()
            }
            .buttonStyle(.borderedProminent)
            Button("無視") {
                watcher.dismissPending()
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.thinMaterial)
    }
}
