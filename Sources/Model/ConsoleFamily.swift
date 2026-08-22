import Foundation

/// Which MA Lighting console generation a Source's folder layout follows.
/// Only USB sources let the user pick MA2 — Local (onPC) and the SFTP
/// console connection stay grandMA3-only, per how this app is actually used.
enum ConsoleFamily: String, Codable, CaseIterable {
    case ma3
    case ma2

    var displayName: String {
        switch self {
        case .ma3: return "grandMA3"
        case .ma2: return "grandMA2"
        }
    }

    /// Compact form for badges, e.g. in the sidebar's Source rows.
    var shortLabel: String {
        switch self {
        case .ma3: return "MA3"
        case .ma2: return "MA2"
        }
    }

    /// The marker folder this family creates at a USB volume's root.
    var usbRootFolderName: String {
        switch self {
        case .ma3: return "grandMA3"
        case .ma2: return "gma2"
        }
    }

    var categories: [ConsoleCategory] {
        switch self {
        case .ma3: return MA3FolderTaxonomy.categories
        case .ma2: return MA2FolderTaxonomy.categories
        }
    }
}
