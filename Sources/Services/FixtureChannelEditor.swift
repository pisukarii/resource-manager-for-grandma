import Foundation

/// One row of the fixture type editor's DMXChannels table (the columns the
/// grandMA3 fixture type editor shows), for either a GDTF or a grandMA3
/// fixture-type XML. Values are shown the way the editor shows them: DMX
/// values as the coarse byte 0...255, offsets as 1-based DMX addresses.
struct DMXChannelRow: Identifiable, Equatable {
    /// Compares only what the table can edit (the read-only `functions`
    /// detail is ignored), so "was this row changed?" is exact.
    static func == (a: DMXChannelRow, b: DMXChannelRow) -> Bool {
        a.id == b.id && a.dmxBreak == b.dmxBreak && a.coarse == b.coarse && a.fine == b.fine
            && a.ultra == b.ultra && a.defaultValue == b.defaultValue && a.highlight == b.highlight
            && a.lowlight == b.lowlight && a.snap == b.snap
    }

    struct Function: Equatable {
        let name: String
        let attribute: String
        let dmxFrom: String
        let defaultValue: String
        let physical: String
        let setCount: Int
    }

    /// Position among the mode's DMXChannel elements (stable identity).
    let id: Int
    /// "<geometry>_<attribute>", as the editor names a channel. Read-only.
    let name: String
    /// First logical channel's attribute (Pan, Dimmer, ...). Read-only.
    let attribute: String
    let functions: [Function]

    var dmxBreak: Int?
    var coarse: Int?
    var fine: Int?
    var ultra: Int?
    var defaultValue: Int?
    var highlight: Int?
    var lowlight: Int?
    var snap: Bool
}

struct DMXModeChannels: Equatable {
    let name: String
    var rows: [DMXChannelRow]
}

/// What a given format can actually store, so the table disables the rest.
struct DMXChannelCapabilities {
    let hasBreak: Bool      // GDTF only
    let hasLowlight: Bool   // grandMA3 XML only (GDTF has no lowlight)

    static func of(_ format: FixtureInfo.Format) -> DMXChannelCapabilities {
        switch format {
        case .gdtf: return .init(hasBreak: true, hasLowlight: false)
        case .ma3xml: return .init(hasBreak: false, hasLowlight: true)
        }
    }
}

enum FixtureChannelEditor {

    // MARK: Parse

    static func parseModes(xmlData: Data, format: FixtureInfo.Format) -> [DMXModeChannels] {
        guard let doc = try? XMLDocument(data: xmlData, options: [.nodeLoadExternalEntitiesNever]),
              let modes = try? doc.nodes(forXPath: "//FixtureType//DMXModes/DMXMode") else { return [] }
        return modes.compactMap { $0 as? XMLElement }.map { mode in
            let channels = (try? mode.nodes(forXPath: "DMXChannels/DMXChannel")) ?? []
            let rows = channels.compactMap { $0 as? XMLElement }.enumerated().map { index, channel in
                parseRow(channel, index: index, format: format)
            }
            return DMXModeChannels(name: attr(mode, "Name") ?? "", rows: rows)
        }
    }

    private static func parseRow(_ channel: XMLElement, index: Int, format: FixtureInfo.Format) -> DMXChannelRow {
        let logicals = (channel.children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == "LogicalChannel" }
        let attribute = logicals.first.flatMap { attr($0, "Attribute") } ?? ""
        let geometry = attr(channel, "Geometry") ?? ""
        let geometryName = geometry.split(separator: ".").last.map(String.init) ?? geometry
        let name = [geometryName, attribute].filter { !$0.isEmpty }.joined(separator: "_")

        let functions: [DMXChannelRow.Function] = logicals.flatMap { logical in
            (logical.children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == "ChannelFunction" }.map { function in
                let from = attr(function, "PhysicalFrom") ?? ""
                let to = attr(function, "PhysicalTo") ?? ""
                return DMXChannelRow.Function(
                    name: attr(function, "Name") ?? "",
                    attribute: attr(function, "Attribute") ?? "",
                    dmxFrom: attr(function, "DMXFrom") ?? "",
                    defaultValue: attr(function, "Default") ?? "",
                    physical: (from.isEmpty && to.isEmpty) ? "" : "\(from) → \(to)",
                    setCount: (function.children ?? []).filter { ($0 as? XMLElement)?.name == "ChannelSet" }.count
                )
            }
        }
        let snap = logicals.contains { attr($0, "Snap")?.caseInsensitiveCompare("Yes") == .orderedSame }

        switch format {
        case .gdtf:
            let offsets = (attr(channel, "Offset") ?? "")
                .split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
            func offset(_ i: Int) -> Int? { i < offsets.count ? offsets[i] : nil }
            return DMXChannelRow(
                id: index, name: name, attribute: attribute, functions: functions,
                dmxBreak: Int(attr(channel, "DMXBreak") ?? ""),
                coarse: offset(0), fine: offset(1), ultra: offset(2),
                defaultValue: gdtfCoarse(initialFunction(of: channel, logicals: logicals).flatMap { attr($0, "Default") }),
                highlight: gdtfCoarse(attr(channel, "Highlight")),
                lowlight: nil,
                snap: snap
            )
        case .ma3xml:
            return DMXChannelRow(
                id: index, name: name, attribute: attribute, functions: functions,
                dmxBreak: nil,
                coarse: Int(attr(channel, "Coarse") ?? ""),
                fine: Int(attr(channel, "Fine") ?? ""),
                ultra: Int(attr(channel, "Ultra") ?? ""),
                defaultValue: hexCoarse(attr(channel, "Default")),
                highlight: hexCoarse(attr(channel, "Highlight")),
                lowlight: hexCoarse(attr(channel, "Lowlight")),
                snap: snap
            )
        }
    }

    // MARK: Apply edits

    enum EditError: LocalizedError {
        case missing(String)
        var errorDescription: String? {
            switch self {
            case .missing(let what): return "編集対象が見つかりませんでした(\(what))。"
            }
        }
    }

    /// Returns the document with only the changed cells rewritten. Every
    /// untouched attribute, element, and the original ordering is preserved.
    static func apply(
        edited: [DMXModeChannels], original: [DMXModeChannels],
        to xmlData: Data, format: FixtureInfo.Format
    ) throws -> Data {
        let hadBOM = xmlData.starts(with: [0xEF, 0xBB, 0xBF])
        let doc = try XMLDocument(data: xmlData, options: [.nodePreserveAll, .nodeLoadExternalEntitiesNever])
        let modeNodes = try doc.nodes(forXPath: "//FixtureType//DMXModes/DMXMode").compactMap { $0 as? XMLElement }

        for (modeIndex, mode) in edited.enumerated() where modeIndex < original.count && modeIndex < modeNodes.count {
            let channelNodes = try modeNodes[modeIndex].nodes(forXPath: "DMXChannels/DMXChannel").compactMap { $0 as? XMLElement }
            for row in mode.rows {
                guard row.id < original[modeIndex].rows.count else { continue }
                let before = original[modeIndex].rows[row.id]
                guard row != before else { continue }
                guard row.id < channelNodes.count else { throw EditError.missing("\(mode.name) / チャンネル \(row.id + 1)") }
                switch format {
                case .gdtf: applyGDTF(row, before: before, to: channelNodes[row.id])
                case .ma3xml: applyMA3(row, before: before, to: channelNodes[row.id])
                }
            }
        }
        var out = doc.xmlData(options: [.nodePreserveAll])
        // Foundation writes `standalone="yes"` and runs the root element onto the
        // declaration line; put it back the way MA writes these files.
        if var text = String(data: out, encoding: .utf8), text.hasPrefix("<?xml"), let end = text.range(of: "?>") {
            var declaration = String(text[..<end.upperBound]).replacingOccurrences(of: " standalone=\"yes\"", with: "")
            declaration += "\n"
            var rest = String(text[end.upperBound...])
            if rest.hasPrefix("\n") { rest.removeFirst() }
            text = declaration + rest
            out = Data(text.utf8)
        }
        if hadBOM && !out.starts(with: [0xEF, 0xBB, 0xBF]) { out = Data([0xEF, 0xBB, 0xBF]) + out }
        return out
    }

    private static func applyMA3(_ row: DMXChannelRow, before: DMXChannelRow, to channel: XMLElement) {
        setInt(row.coarse, "Coarse", on: channel)
        setInt(row.fine, "Fine", on: channel)
        setInt(row.ultra, "Ultra", on: channel)
        if row.defaultValue != before.defaultValue { setHex(row.defaultValue, "Default", on: channel) }
        if row.highlight != before.highlight { setHex(row.highlight, "Highlight", on: channel) }
        if row.lowlight != before.lowlight { setHex(row.lowlight, "Lowlight", on: channel) }
        if row.snap != before.snap { setSnap(row.snap, on: channel, yesNo: false) }
    }

    private static func applyGDTF(_ row: DMXChannelRow, before: DMXChannelRow, to channel: XMLElement) {
        let logicals = (channel.children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == "LogicalChannel" }
        let oldBytes = before.byteCount
        let offsets = [row.coarse, row.fine, row.ultra].prefix { $0 != nil }.compactMap { $0 }
        let newBytes = offsets.count

        if row.coarse != before.coarse || row.fine != before.fine || row.ultra != before.ultra {
            setString(offsets.isEmpty ? "None" : offsets.map(String.init).joined(separator: ","), "Offset", on: channel)
        }
        if row.dmxBreak != before.dmxBreak, let value = row.dmxBreak { setString(String(value), "DMXBreak", on: channel) }

        // The stored value is "value/bytes": if the byte count changed, rescale the
        // untouched value so it keeps meaning the same thing at the new resolution.
        let rescale = newBytes != oldBytes && newBytes > 0
        if row.highlight != before.highlight || rescale {
            if let h = row.highlight { setString(gdtfString(h, bytes: max(newBytes, 1)), "Highlight", on: channel) }
            else { setString("None", "Highlight", on: channel) }
        }
        if row.defaultValue != before.defaultValue || rescale,
           let value = row.defaultValue, let function = initialFunction(of: channel, logicals: logicals) {
            setString(gdtfString(value, bytes: max(newBytes, 1)), "Default", on: function)
        }
        if row.snap != before.snap { setSnap(row.snap, on: channel, yesNo: true) }
    }

    // MARK: Helpers

    private static func attr(_ element: XMLElement, _ name: String) -> String? {
        element.attribute(forName: name)?.stringValue
    }

    private static func setString(_ value: String, _ name: String, on element: XMLElement) {
        if let existing = element.attribute(forName: name) { existing.stringValue = value }
        else { element.addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode) }
    }

    private static func setInt(_ value: Int?, _ name: String, on element: XMLElement) {
        if let value { setString(String(value), name, on: element) } else { element.removeAttribute(forName: name) }
    }

    /// grandMA3 stores values as 24-bit hex ("800000"); the editor shows the
    /// top byte. Editing changes that byte and keeps the rest.
    private static func setHex(_ value: Int?, _ name: String, on element: XMLElement) {
        guard let value else { element.removeAttribute(forName: name); return }
        let byte = String(format: "%02X", max(0, min(255, value)))
        let existing = attr(element, name) ?? "000000"
        let tail = existing.count > 2 ? String(existing.dropFirst(2)) : "0000"
        setString(byte + tail, name, on: element)
    }

    private static func setSnap(_ snap: Bool, on channel: XMLElement, yesNo: Bool) {
        let logicals = (channel.children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == "LogicalChannel" }
        for logical in logicals {
            if yesNo { setString(snap ? "Yes" : "No", "Snap", on: logical) }
            else if snap { setString("Yes", "Snap", on: logical) }
            else { logical.removeAttribute(forName: "Snap") }
        }
    }

    /// GDTF: `InitialFunction="<channel>.<logical>.<function>"`, else the first function.
    private static func initialFunction(of channel: XMLElement, logicals: [XMLElement]) -> XMLElement? {
        let all = logicals.flatMap { logical in
            (logical.children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == "ChannelFunction" }
        }
        if let path = attr(channel, "InitialFunction"), let last = path.split(separator: ".").last,
           let match = all.first(where: { attr($0, "Name") == String(last) }) {
            return match
        }
        return all.first
    }

    /// "value/bytes" -> coarse byte.
    private static func gdtfCoarse(_ text: String?) -> Int? {
        guard let text, text.lowercased() != "none" else { return nil }
        let parts = text.split(separator: "/")
        guard let value = Int(parts.first ?? ""), value >= 0 else { return nil }
        let bytes = max(Int(parts.count > 1 ? parts[1] : "1") ?? 1, 1)
        return min(255, value >> (8 * (bytes - 1)))
    }

    private static func gdtfString(_ coarse: Int, bytes: Int) -> String {
        "\(max(0, min(255, coarse)) << (8 * (bytes - 1)))/\(bytes)"
    }

    private static func hexCoarse(_ text: String?) -> Int? {
        guard let text, text.count >= 2 else { return nil }
        return Int(text.prefix(2), radix: 16)
    }
}

private extension DMXChannelRow {
    /// Bytes this channel occupies (coarse/fine/ultra in a row from coarse).
    var byteCount: Int { [coarse, fine, ultra].prefix { $0 != nil }.count }
}

// MARK: Validation

enum DMXChannelValidator {
    /// Human-readable problems that make a mode's channel layout invalid.
    static func problems(in mode: DMXModeChannels, format: FixtureInfo.Format) -> [Int: String] {
        var issues: [Int: String] = [:]
        var owner: [String: Int] = [:]   // "break/address" -> row id
        for row in mode.rows {
            if row.coarse == nil, row.fine != nil || row.ultra != nil {
                issues[row.id] = "Coarseが空のままFine/Ultraは設定できません"
                continue
            }
            if row.fine == nil, row.ultra != nil {
                issues[row.id] = "FineなしでUltraは設定できません"
                continue
            }
            let breakKey = format == .gdtf ? (row.dmxBreak ?? 1) : 1
            for address in [row.coarse, row.fine, row.ultra].compactMap({ $0 }) {
                if !(1...512).contains(address) {
                    issues[row.id] = "アドレスは1〜512の範囲です"
                    continue
                }
                let key = "\(breakKey)/\(address)"
                if let other = owner[key] {
                    issues[row.id] = "アドレス\(address)が別のチャンネル(No.\(other + 1))と重複しています"
                    issues[other] = issues[other] ?? "アドレス\(address)が別のチャンネル(No.\(row.id + 1))と重複しています"
                } else {
                    owner[key] = row.id
                }
            }
        }
        return issues
    }
}
