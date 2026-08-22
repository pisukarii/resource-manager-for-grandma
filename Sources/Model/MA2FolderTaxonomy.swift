import Foundation

/// grandMA2 USB layout, rooted at `<volume>/gma2/`.
///
/// Verified via MA Lighting documentation (2026-08-19): the `gma2` folder
/// contains `shows`, `bitmaps`, `colors`, `effects`, `gobos`, and
/// `importexport` at its top level. Unlike grandMA3's `gma3_library`, the
/// exact per-object-type subfolder names *inside* `importexport` (macros,
/// presets, sequences, etc.) could not be confirmed from documentation
/// alone — rather than guess and risk wrong shortcuts, this taxonomy only
/// covers the confirmed top-level folders plus a generic "Import/Export"
/// entry the user can drill into manually. If you verify the exact
/// `importexport` subfolder names against a real MA2 USB stick, add them
/// here the same way `MA3FolderTaxonomy` breaks down `datapools/*`.
enum MA2FolderTaxonomy {
    static let categories: [ConsoleCategory] = [
        ConsoleCategory(id: "ma2_shows", displayName: "Shows", symbolName: "theatermasks", rootKind: .library,
                    relativePath: RelativePath(components: ["shows"])),
        ConsoleCategory(id: "ma2_importexport", displayName: "Import/Export", symbolName: "square.and.arrow.up.on.square", rootKind: .library,
                    relativePath: RelativePath(components: ["importexport"])),
        ConsoleCategory(id: "ma2_effects", displayName: "Effects", symbolName: "sparkles", rootKind: .library,
                    relativePath: RelativePath(components: ["effects"])),
        ConsoleCategory(id: "ma2_gobos", displayName: "Gobos", symbolName: "circle.grid.cross", rootKind: .library,
                    relativePath: RelativePath(components: ["gobos"])),
        ConsoleCategory(id: "ma2_bitmaps", displayName: "Bitmaps", symbolName: "square.grid.3x3.square", rootKind: .library,
                    relativePath: RelativePath(components: ["bitmaps"])),
        ConsoleCategory(id: "ma2_colors", displayName: "Colors", symbolName: "paintpalette", rootKind: .library,
                    relativePath: RelativePath(components: ["colors"])),
    ]
}
