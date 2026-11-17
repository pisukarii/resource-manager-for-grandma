import AppKit
import Foundation

/// Adds downloaded GDTF files to grandMA3's user fixture library, the folder
/// MA3's Patch > Fixture Types > Import lists as the user library.
@MainActor
enum GDTFLibrary {
    struct Added {
        let fileName: String
        let fixture: String        // "Manufacturer — Model" read from the file
    }

    enum Outcome {
        case added(Added)
        case skipped(String)       // user declined to overwrite
        case failed(String)
    }

    static var destinationFolder: URL {
        MA3LocalDetector.malightingRoot
            .appendingPathComponent("gma3_library", isDirectory: true)
            .appendingPathComponent("fixturetypes", isDirectory: true)
    }

    /// Validates `url` as a GDTF (a zip with a readable description.xml) and
    /// copies it into the library. An existing file of the same name is only
    /// replaced after the user confirms.
    static func add(_ url: URL) async -> Outcome {
        let name = url.lastPathComponent
        guard url.pathExtension.lowercased() == "gdtf" else {
            return .failed("「\(name)」は.gdtfファイルではありません。")
        }
        guard let reader = ZipReader(url: url), let description = reader.read("description.xml"),
              let info = FixtureParser.parse(xmlData: description, format: .gdtf) else {
            return .failed("「\(name)」はGDTFとして読み込めませんでした(壊れているか、ダウンロードが途中の可能性があります)。")
        }
        let fm = FileManager.default
        let target = destinationFolder.appendingPathComponent(name)
        do {
            try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            if fm.fileExists(atPath: target.path) {
                let alert = NSAlert()
                alert.messageText = "上書きの確認"
                alert.informativeText = "「\(name)」は既にライブラリに存在します。上書きしますか？"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "上書き")
                alert.addButton(withTitle: "キャンセル")
                guard alert.runModal() == .alertFirstButtonReturn else { return .skipped(name) }
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: url, to: target)
        } catch {
            return .failed("「\(name)」を追加できませんでした: \(error.localizedDescription)")
        }
        let label = [info.manufacturer, info.name].filter { !$0.isEmpty }.joined(separator: " — ")
        return .added(Added(fileName: name, fixture: label))
    }
}
