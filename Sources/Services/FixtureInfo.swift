import Foundation

/// A read-only summary of a fixture type, parsed from either a GDTF's
/// `description.xml` or a grandMA3 fixture-type XML (`GMA3/FixtureType`) —
/// the two share the same `FixtureType` / `DMXModes` / `Wheels` structure.
struct FixtureInfo {
    enum Format { case gdtf, ma3xml }

    struct Mode: Identifiable {
        var id: String { name }
        let name: String
        let channelCount: Int
    }

    struct Slot: Identifiable {
        let id: String            // "wheelIndex.slotIndex"
        let wheelIndex: Int
        let slotIndex: Int
        let name: String
        /// GDTF: image file name without extension, stored as `wheels/<name>.png`.
        let mediaFileName: String?
        /// The slot's `Color` attribute as written (GDTF "x,y,Y" CIE, or MA3 "R,G,B,A").
        let color: String?

        /// Prism slots: where each facet sends its copy of the beam.
        let facets: [Facet]

        /// Display colour for a colour-wheel slot, if the slot defines one.
        var rgb: SlotColor? { SlotColor.parse(color) }
    }

    /// One prism facet. `x`/`y` are the beam's offset from the optical axis,
    /// read from the translation part of the facet's `Rotation` matrix
    /// (`{1,0,x}{0,1,y}{0,0,1}`), in units where 0.5 is the usual ring radius.
    struct Facet: Equatable {
        let x: Double
        let y: Double
        let color: SlotColor?
    }

    struct Wheel: Identifiable {
        var id: Int { index }
        let index: Int
        let name: String
        let slots: [Slot]
        /// Only gobo wheels get image swapping (colour slots have no image).
        var isGobo: Bool { name.localizedCaseInsensitiveContains("gobo") }
    }

    let format: Format
    let name: String
    let shortName: String
    let manufacturer: String
    let description: String
    let fixtureTypeID: String
    let modes: [Mode]
    let wheels: [Wheel]
}

/// sRGB display colour (0...1) of a wheel slot.
struct SlotColor: Equatable {
    let r: Double
    let g: Double
    let b: Double
    /// Light transmitted, 0...1, when the file records it (GDTF's Y).
    let transmission: Double?

    /// GDTF writes "x,y,Y" (CIE 1931 chromaticity, Y in percent); grandMA3's
    /// own XML writes "R,G,B,A" floats. The swatch shows the hue at full
    /// strength — a 12%-transmission red filter would otherwise look black.
    static func parse(_ text: String?) -> SlotColor? {
        guard let text else { return nil }
        let v = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if v.count >= 4 {
            return SlotColor(r: clamp(v[0]), g: clamp(v[1]), b: clamp(v[2]), transmission: nil)
        }
        guard v.count == 3, v[1] > 0 else { return nil }
        let x = v[0], y = v[1], luminance = max(v[2], 0) / 100
        // xyY -> XYZ (Y = 1 for the hue), -> linear sRGB (D65).
        let bigX = x / y, bigZ = (1 - x - y) / y
        var lr = 3.2406 * bigX - 1.5372 - 0.4986 * bigZ
        var lg = -0.9689 * bigX + 1.8758 + 0.0415 * bigZ
        var lb = 0.0557 * bigX - 0.2040 + 1.0570 * bigZ
        lr = max(lr, 0); lg = max(lg, 0); lb = max(lb, 0)
        let peak = max(lr, lg, lb)
        guard peak > 0 else { return SlotColor(r: 0, g: 0, b: 0, transmission: luminance) }
        func gamma(_ c: Double) -> Double {
            let n = c / peak
            return n <= 0.0031308 ? 12.92 * n : 1.055 * pow(n, 1 / 2.4) - 0.055
        }
        return SlotColor(r: clamp(gamma(lr)), g: clamp(gamma(lg)), b: clamp(gamma(lb)), transmission: luminance)
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}

enum FixtureParser {
    /// Returns nil when the data isn't a fixture-type document (e.g. any
    /// other XML such as a gobo descriptor or macro).
    static func parse(xmlData: Data, format: FixtureInfo.Format) -> FixtureInfo? {
        guard let doc = try? XMLDocument(data: xmlData, options: [.nodeLoadExternalEntitiesNever]),
              let fixtureType = (try? doc.nodes(forXPath: "//FixtureType"))?.first as? XMLElement else {
            return nil
        }
        func attr(_ element: XMLElement, _ name: String) -> String {
            element.attribute(forName: name)?.stringValue ?? ""
        }

        let modes: [FixtureInfo.Mode] = ((try? fixtureType.nodes(forXPath: ".//DMXModes/DMXMode")) ?? [])
            .compactMap { $0 as? XMLElement }
            .map { mode in
                let count = (try? mode.nodes(forXPath: ".//DMXChannel"))?.count ?? 0
                return FixtureInfo.Mode(name: attr(mode, "Name"), channelCount: count)
            }

        let wheelElements = ((try? fixtureType.nodes(forXPath: ".//Wheels/Wheel")) ?? []).compactMap { $0 as? XMLElement }
        let wheels: [FixtureInfo.Wheel] = wheelElements.enumerated().map { wheelIndex, wheel in
            let slotElements = (wheel.children ?? []).compactMap { $0 as? XMLElement }
            let slots = slotElements.enumerated().map { slotIndex, slot -> FixtureInfo.Slot in
                let media = attr(slot, "MediaFileName")
                let color = attr(slot, "Color")
                let facets = (slot.children ?? []).compactMap { $0 as? XMLElement }
                    .filter { $0.name == "Facet" }
                    .map { facet in
                        let (x, y) = Self.facetOffset(attr(facet, "Rotation"))
                        return FixtureInfo.Facet(x: x, y: y, color: SlotColor.parse(attr(facet, "Color")))
                    }
                return FixtureInfo.Slot(
                    id: "\(wheelIndex).\(slotIndex)",
                    wheelIndex: wheelIndex,
                    slotIndex: slotIndex,
                    name: attr(slot, "Name"),
                    mediaFileName: media.isEmpty ? nil : media,
                    color: color.isEmpty ? nil : color,
                    facets: facets
                )
            }
            return FixtureInfo.Wheel(index: wheelIndex, name: attr(wheel, "Name"), slots: slots)
        }

        return FixtureInfo(
            format: format,
            name: attr(fixtureType, "Name"),
            shortName: attr(fixtureType, "ShortName"),
            manufacturer: attr(fixtureType, "Manufacturer"),
            description: attr(fixtureType, "Description"),
            fixtureTypeID: attr(fixtureType, "FixtureTypeID"),
            modes: modes,
            wheels: wheels
        )
    }

    /// "{1,0,0.5}{0,1,0}{0,0,1}" -> (0.5, 0): the matrix's translation column.
    private static func facetOffset(_ rotation: String) -> (Double, Double) {
        let numbers = rotation
            .replacingOccurrences(of: "{", with: " ").replacingOccurrences(of: "}", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ").compactMap { Double($0) }
        guard numbers.count >= 9 else { return (0, 0) }
        return (numbers[2], numbers[5])
    }

    /// Returns `description.xml` with `MediaFileName` set on one wheel slot.
    static func settingMediaFileName(_ media: String, wheelIndex: Int, slotIndex: Int, in xmlData: Data) throws -> Data {
        let doc = try XMLDocument(data: xmlData, options: [.nodePreserveAll, .nodeLoadExternalEntitiesNever])
        let wheels = try doc.nodes(forXPath: "//FixtureType//Wheels/Wheel")
        guard wheelIndex < wheels.count, let wheel = wheels[wheelIndex] as? XMLElement else {
            throw FileSourceError.underlying("GDTFのホイール定義が見つかりませんでした。")
        }
        let slots = (wheel.children ?? []).compactMap { $0 as? XMLElement }
        guard slotIndex < slots.count else {
            throw FileSourceError.underlying("GDTFのスロット定義が見つかりませんでした。")
        }
        slots[slotIndex].addAttribute(XMLNode.attribute(withName: "MediaFileName", stringValue: media) as! XMLNode)
        return doc.xmlData(options: [.nodePreserveAll])
    }
}

/// Reads a GDTF (a zip) with `ZipReader`, and writes updated copies with the
/// system `zip` tool — Foundation has no zip API, and `zip` ships with macOS.
enum GDTFArchive {
    private static func run(_ executable: String, _ arguments: [String], in directory: URL? = nil) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        // Read before waiting, so a large entry can't fill the pipe and deadlock.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FileSourceError.underlying("GDTFを読み書きできませんでした(zip形式ではない、または壊れている可能性があります)。")
        }
        return data
    }

    static func read(_ archive: URL, entry: String) throws -> Data {
        guard let reader = ZipReader(url: archive), let data = reader.read(entry) else {
            throw FileSourceError.underlying("GDTFを読み込めませんでした(zip形式ではない、または壊れている可能性があります)。")
        }
        return data
    }

    static func description(of archive: URL) throws -> Data {
        try read(archive, entry: "description.xml")
    }

    static func entryNames(of archive: URL) -> Set<String> {
        Set(ZipReader(url: archive)?.names ?? [])
    }

    /// Writes a copy of `archive` with `entries` (path inside the zip -> data)
    /// added or replaced, to `destination`. The original is never touched.
    static func writeUpdatedCopy(of archive: URL, entries: [String: Data], to destination: URL) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: archive, to: destination)

        for (path, data) in entries {
            let file = work.appendingPathComponent(path)
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file)
        }
        _ = try run("/usr/bin/zip", ["-q", "-X", destination.path] + entries.keys.sorted(), in: work)
    }
}
