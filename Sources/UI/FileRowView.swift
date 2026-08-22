import SwiftUI

struct FileRowView: View {
    let entry: FileEntry
    var isSelectionMode: Bool = false
    var isChecked: Bool = false
    var onToggleCheck: (() -> Void)? = nil

    var body: some View {
        HStack {
            if isSelectionMode {
                Button {
                    onToggleCheck?()
                } label: {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            Image(systemName: entry.isDirectory ? Self.folderIconName(for: entry.name) : "doc")
                .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                .frame(width: 20)
            Text(entry.name)
            Spacer()
            if let size = entry.size, !entry.isDirectory {
                Text(formattedSize(size))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let date = entry.modifiedDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: isSelectionMode)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Gives well-known MA3 resource folders (the "lib_*" folders inside
    /// "Resource", plus a few siblings) the same kind of distinctive icon
    /// the category sidebar uses, instead of one generic folder icon for
    /// everything — makes a flat wall of folders (e.g. Resource's ~35
    /// entries) scannable at a glance.
    private static let knownFolderIcons: [String: String] = [
        "lib_addons": "puzzlepiece.extension.fill",
        "lib_agendas": "calendar",
        "lib_bitmaps": "square.grid.3x3.square",
        "lib_color_themes": "swatchpalette.fill",
        "lib_dmxcurves": "waveform.path.ecg",
        "lib_filters": "line.3.horizontal.decrease.circle",
        "lib_fixture_types": "lightbulb.2",
        "lib_gels": "drop.fill",
        "lib_generators": "waveform.path",
        "lib_images": "photo",
        "lib_keyboard_shortcuts": "keyboard",
        "lib_macros": "chevron.left.forwardslash.chevron.right",
        "lib_matricks": "square.grid.3x3",
        "lib_meshes": "cube.transparent",
        "lib_mvr": "cube.fill",
        "lib_net_duct": "cable.connector",
        "lib_plugins": "puzzlepiece.fill",
        "lib_presets": "slider.horizontal.3",
        "lib_quickeys": "command",
        "lib_render_qualities": "sparkles",
        "lib_symbols": "star.fill",
        "lib_videos": "film.fill",
        "lib_viz": "eye.fill",
        "demoshows": "theatermasks.fill",
        "fonts": "textformat",
        "keyboards": "keyboard.fill",
        "software": "gearshape.2.fill",
        "textures": "square.on.square",
        "web": "globe",
    ]

    private static func folderIconName(for name: String) -> String {
        if let icon = knownFolderIcons[name] { return icon }
        if name.hasPrefix("lib_menus") { return "menucard.fill" }
        if name.hasPrefix("shaders") { return "wand.and.stars" }
        return "folder.fill"
    }
}
