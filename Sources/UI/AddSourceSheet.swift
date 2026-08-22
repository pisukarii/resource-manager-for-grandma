import SwiftUI
import AppKit

struct AddSourceSheet: View {
    @Environment(SourceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var kind: SourceKind = .local
    @State private var detectedVersionFolders: [MA3LocalDetector.VersionFolder] = []
    @State private var detectedUSBVolumes: [DetectedUSBSource] = []
    @State private var manualUSBFamily: ConsoleFamily = .ma3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sourceを追加")
                .font(.title3.bold())

            Picker("種類", selection: $kind.animation(.easeInOut(duration: 0.2))) {
                ForEach(SourceKind.allCases, id: \.self) { k in
                    Label(k.displayName, systemImage: k.symbolName).tag(k)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch kind {
                case .local:
                    localSection
                case .usb:
                    usbSection
                case .sftp:
                    sftpSection
                }
            }
            .transition(.opacity.combined(with: .move(edge: .leading)))
            .id(kind)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: kind == .sftp ? 620 : 340)
        .onAppear {
            detectedVersionFolders = MA3LocalDetector.detectVersionFolders()
            detectedUSBVolumes = USBVolumeWatcher.detectMountedConsoleVolumes()
        }
    }

    private var localSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if detectedVersionFolders.isEmpty {
                Text("~/MALightingTechnology 内に onPC のバージョンフォルダが見つかりませんでした。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                Text("検出された onPC バージョン:")
                    .font(.callout.bold())
                List(detectedVersionFolders) { folder in
                    Button {
                        addLocal(name: "onPC \(folder.name)", url: folder.url)
                    } label: {
                        HStack {
                            Image(systemName: "laptopcomputer")
                            Text(folder.name)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 140)
            }

            Button("フォルダを手動で選択...") {
                pickLocalFolder()
            }
        }
    }

    private var usbSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if detectedUSBVolumes.isEmpty {
                Text("grandMA3 (grandMA3フォルダ) / grandMA2 (gma2フォルダ) いずれの USB ボリュームも見つかりませんでした。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                Text("検出された USB:")
                    .font(.callout.bold())
                List(detectedUSBVolumes) { detection in
                    Button {
                        addUSB(detection)
                    } label: {
                        HStack {
                            Image(systemName: "externaldrive")
                            Text(detection.volumeURL.lastPathComponent)
                            Text(detection.family.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 140)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("自動検出されない場合は手動で選択してください:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("コンソール種別", selection: $manualUSBFamily) {
                    ForEach(ConsoleFamily.allCases, id: \.self) { family in
                        Text(family.displayName).tag(family)
                    }
                }
                .pickerStyle(.segmented)
                Button("ボリュームを手動で選択...") {
                    pickUSBVolume()
                }
            }
        }
    }

    private var sftpSection: some View {
        SFTPConnectionForm()
    }

    private func pickLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = MA3LocalDetector.malightingRoot
        panel.prompt = "選択"
        if panel.runModal() == .OK, let url = panel.url {
            addLocal(name: url.lastPathComponent, url: url)
        }
    }

    private func pickUSBVolume() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        panel.prompt = "選択"
        if panel.runModal() == .OK, let url = panel.url {
            if let detected = USBVolumeWatcher.detectConsoleFolder(at: url) {
                addUSB(detected)
            } else {
                // Not auto-detected (e.g. the user picked the data-root
                // folder itself, or it doesn't match either marker folder
                // name) — fall back to the manually chosen family.
                addLocal(name: url.lastPathComponent, url: url, kind: .usb, family: manualUSBFamily)
            }
        }
    }

    private func addUSB(_ detection: DetectedUSBSource) {
        addLocal(name: detection.volumeURL.lastPathComponent, url: detection.dataRootURL, kind: .usb, family: detection.family)
    }

    private func addLocal(name: String, url: URL, kind: SourceKind = .local, family: ConsoleFamily? = nil) {
        let bookmark = BookmarkStore.makeBookmark(for: url)
        let config = SourceConfig(name: name, kind: kind, path: url.path, bookmarkData: bookmark, family: family)
        store.addSource(config)
        dismiss()
    }
}
