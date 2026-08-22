import Foundation

/// Whether a category lives under the version-specific `shared/` folder
/// (needs the onPC version folder name prefixed) or under the
/// version-independent `gma3_library/` tree (shared across all installed
/// onPC versions, and the whole thing on USB/console under `grandMA3/`).
enum ConsoleCategoryRootKind {
    case versionScoped
    case library
}

/// One well-known grandMA3 file category (Shows, Macros, Sequences, ...).
///
/// `relativePath` is the path from the *category root* (see `rootKind`) to
/// this category, shared by every backend. Each `FileSource` resolves the
/// actual root prefix for a given category (see `FileSource.rootPrefix(for:)`)
/// so the same taxonomy works whether the root is a USB volume's `grandMA3`
/// folder, an onPC install's `MALightingTechnology` folder, or a console's
/// SFTP root.
struct ConsoleCategory: Identifiable, Hashable {
    let id: String
    let displayName: String
    let symbolName: String
    let rootKind: ConsoleCategoryRootKind
    let relativePath: RelativePath
}

enum MA3FolderTaxonomy {
    /// Verified against a real onPC install (`~/MALightingTechnology`) on 2026-08-18:
    /// - `~/MALightingTechnology/gma3_x.y.z/shared/{shows,backups}` — version-scoped.
    /// - `~/MALightingTechnology/gma3_library/...` — shared across all installed
    ///   versions, a *sibling* of the `gma3_x.y.z` folders, not nested inside one.
    /// - USB layout mirrors this uniformly under `<volume>/grandMA3/` (no
    ///   per-version split there).
    /// - Console SFTP layout is unconfirmed — verify against a real console
    ///   and adjust `ConsoleSFTPSource`'s root resolution if it differs.
    static let categories: [ConsoleCategory] = [
        ConsoleCategory(id: "shows", displayName: "Shows", symbolName: "theatermasks", rootKind: .versionScoped,
                    relativePath: RelativePath(components: ["shared", "shows"])),
        ConsoleCategory(id: "backups", displayName: "Backups", symbolName: "clock.arrow.circlepath", rootKind: .versionScoped,
                    relativePath: RelativePath(components: ["shared", "backups"])),
        ConsoleCategory(id: "lib_fixture_types", displayName: "Fixture Library", symbolName: "lightbulb.2", rootKind: .versionScoped,
                    relativePath: RelativePath(components: ["shared", "lib_fixture_types"])),
        ConsoleCategory(id: "resource", displayName: "Resource", symbolName: "shippingbox", rootKind: .versionScoped,
                    relativePath: RelativePath(components: ["shared", "resource"])),

        ConsoleCategory(id: "macros", displayName: "Macros", symbolName: "chevron.left.forwardslash.chevron.right", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "macros"])),
        ConsoleCategory(id: "sequences", displayName: "Sequences", symbolName: "list.number", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "sequences"])),
        ConsoleCategory(id: "presets", displayName: "Presets", symbolName: "slider.horizontal.3", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "presets"])),
        ConsoleCategory(id: "groups", displayName: "Groups", symbolName: "square.stack.3d.up", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "groups"])),
        ConsoleCategory(id: "layouts", displayName: "Layouts", symbolName: "square.grid.2x2", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "layouts"])),
        ConsoleCategory(id: "executorconfigurations", displayName: "Executor Configs", symbolName: "switch.2", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "executorconfigurations"])),
        ConsoleCategory(id: "executorpages", displayName: "Executor Pages", symbolName: "rectangle.grid.1x2", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "executorpages"])),
        ConsoleCategory(id: "plugins", displayName: "Plugins", symbolName: "puzzlepiece", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "plugins"])),
        ConsoleCategory(id: "quickeys", displayName: "Quick Keys", symbolName: "command", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "quickeys"])),
        ConsoleCategory(id: "timecodes", displayName: "Timecodes", symbolName: "timer", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "timecodes"])),
        ConsoleCategory(id: "matricks", displayName: "Matricks", symbolName: "square.grid.3x3", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "matricks"])),
        ConsoleCategory(id: "shapes", displayName: "Shapes", symbolName: "hexagon", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "shapes"])),
        ConsoleCategory(id: "bitmaps", displayName: "Bitmaps", symbolName: "square.grid.3x3.square", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "bitmaps"])),
        ConsoleCategory(id: "filters", displayName: "Filters", symbolName: "line.3.horizontal.decrease.circle", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "filters"])),
        ConsoleCategory(id: "generators", displayName: "Generators", symbolName: "waveform.path", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "datapools", "generators"])),

        ConsoleCategory(id: "fixturetypes", displayName: "Fixture Types", symbolName: "lightbulb", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "fixturetypes"])),
        ConsoleCategory(id: "fixturetyperesources", displayName: "Fixture Resources", symbolName: "photo.stack", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "fixturetyperesources"])),
        ConsoleCategory(id: "appearances", displayName: "Appearances", symbolName: "paintpalette", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "appearances"])),
        ConsoleCategory(id: "colorthemes", displayName: "Color Themes", symbolName: "swatchpalette", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "colorthemes"])),
        ConsoleCategory(id: "media", displayName: "Media", symbolName: "photo.on.rectangle", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "media"])),
        ConsoleCategory(id: "templateshows", displayName: "Template Shows", symbolName: "doc.on.doc", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "templateshows"])),
        ConsoleCategory(id: "userprofiles", displayName: "User Profiles", symbolName: "person.crop.circle", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "userprofiles"])),
        ConsoleCategory(id: "patch", displayName: "Patch", symbolName: "cable.connector", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "patch"])),
        ConsoleCategory(id: "inout", displayName: "In/Out", symbolName: "arrow.left.arrow.right", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "inout"])),
        ConsoleCategory(id: "agendas", displayName: "Agendas", symbolName: "calendar", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "agendas"])),
        ConsoleCategory(id: "certificates", displayName: "Certificates", symbolName: "checkmark.seal", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "certificates"])),
        ConsoleCategory(id: "mvr", displayName: "MVR", symbolName: "cube", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "mvr"])),
        ConsoleCategory(id: "netkeys", displayName: "Net Keys", symbolName: "key", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "netkeys"])),
        ConsoleCategory(id: "scribbles", displayName: "Scribbles", symbolName: "pencil.and.scribble", rootKind: .library,
                    relativePath: RelativePath(components: ["gma3_library", "scribbles"])),
    ]
}
