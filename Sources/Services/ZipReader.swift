import Foundation
import Compression

/// Minimal read-only zip reader (stored + deflate) for GDTF archives.
///
/// Replaces shelling out to `unzip -p <entry>`, which treats `[ ] * ?` in
/// entry names as wildcards (so a GOBO called "gobo [1]" never loads), needs
/// the name to match byte-for-byte (macOS file names are often Unicode
/// NFD while the XML says NFC), and refuses archives whose central
/// directory is missing. This reads the central directory when present and
/// otherwise walks the local headers, so a truncated file still yields
/// whatever entries are intact.
struct ZipReader {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    let data: Data
    let entries: [Entry]

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count >= 30 else { return nil }
        self.data = data
        let parsed = Self.readCentralDirectory(data) ?? Self.scanLocalHeaders(data)
        guard !parsed.isEmpty else { return nil }
        self.entries = parsed
    }

    var names: [String] { entries.map(\.name) }

    /// Exact name first, then a Unicode-normalised, case-insensitive match.
    func entry(named name: String) -> Entry? {
        if let exact = entries.first(where: { $0.name == name }) { return exact }
        let key = Self.normalized(name)
        return entries.first { Self.normalized($0.name) == key }
    }

    func read(_ name: String) -> Data? {
        guard let entry = entry(named: name) else { return nil }
        return extract(entry)
    }

    func extract(_ entry: Entry) -> Data? {
        let base = data.startIndex
        let header = entry.localOffset
        guard header >= 0, header + 30 <= data.count, Self.u32(data, base + header) == 0x04034b50 else { return nil }
        let nameLength = Int(Self.u16(data, base + header + 26))
        let extraLength = Int(Self.u16(data, base + header + 28))
        let start = header + 30 + nameLength + extraLength
        guard entry.compressedSize >= 0, start + entry.compressedSize <= data.count else { return nil }
        let payload = data.subdata(in: (base + start)..<(base + start + entry.compressedSize))

        switch entry.method {
        case 0:
            return payload
        case 8:
            if entry.uncompressedSize == 0 { return Data() }
            var output = Data(count: entry.uncompressedSize)
            let written = output.withUnsafeMutableBytes { dst in
                payload.withUnsafeBytes { src in
                    compression_decode_buffer(
                        dst.bindMemory(to: UInt8.self).baseAddress!, entry.uncompressedSize,
                        src.bindMemory(to: UInt8.self).baseAddress!, entry.compressedSize,
                        nil, COMPRESSION_ZLIB)
                }
            }
            return written == entry.uncompressedSize ? output : nil
        default:
            return nil
        }
    }

    // MARK: Parsing

    private static func normalized(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static func u16(_ d: Data, _ i: Int) -> UInt16 {
        UInt16(d[i]) | UInt16(d[i + 1]) << 8
    }

    private static func u32(_ d: Data, _ i: Int) -> UInt32 {
        UInt32(d[i]) | UInt32(d[i + 1]) << 8 | UInt32(d[i + 2]) << 16 | UInt32(d[i + 3]) << 24
    }

    private static func decodeName(_ d: Data, utf8Flag: Bool) -> String {
        if let s = String(data: d, encoding: .utf8) { return s }
        return String(data: d, encoding: .isoLatin1) ?? ""
    }

    private static func readCentralDirectory(_ d: Data) -> [Entry]? {
        let base = d.startIndex
        let count = d.count
        guard count >= 22 else { return nil }
        // End-of-central-directory record: last 22 bytes + up to a 64 KB comment.
        var eocd = -1
        var i = count - 22
        let lowest = max(0, count - 22 - 65535)
        while i >= lowest {
            if u32(d, base + i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { return nil }
        let total = Int(u16(d, base + eocd + 10))
        let directoryOffset = Int(u32(d, base + eocd + 16))
        guard directoryOffset != 0xFFFFFFFF, total != 0xFFFF else { return nil } // zip64: use the scan fallback

        var entries: [Entry] = []
        var p = directoryOffset
        for _ in 0..<total {
            guard p + 46 <= count, u32(d, base + p) == 0x02014b50 else { return nil }
            let flags = u16(d, base + p + 8)
            let method = u16(d, base + p + 10)
            let compressed = Int(u32(d, base + p + 20))
            let uncompressed = Int(u32(d, base + p + 24))
            let nameLength = Int(u16(d, base + p + 28))
            let extraLength = Int(u16(d, base + p + 30))
            let commentLength = Int(u16(d, base + p + 32))
            let localOffset = Int(u32(d, base + p + 42))
            guard p + 46 + nameLength <= count, compressed != 0xFFFFFFFF, uncompressed != 0xFFFFFFFF else { return nil }
            let name = decodeName(d.subdata(in: (base + p + 46)..<(base + p + 46 + nameLength)), utf8Flag: flags & 0x800 != 0)
            if !name.hasSuffix("/") {
                entries.append(Entry(name: name, method: method, compressedSize: compressed,
                                     uncompressedSize: uncompressed, localOffset: localOffset))
            }
            p += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    /// Fallback for archives with no (or a damaged) central directory:
    /// walk local headers from the start, keeping entries that are fully
    /// present and whose sizes are recorded up front.
    private static func scanLocalHeaders(_ d: Data) -> [Entry] {
        let base = d.startIndex
        let count = d.count
        var entries: [Entry] = []
        var p = 0
        while p + 30 <= count, u32(d, base + p) == 0x04034b50 {
            let flags = u16(d, base + p + 6)
            let method = u16(d, base + p + 8)
            let compressed = Int(u32(d, base + p + 18))
            let uncompressed = Int(u32(d, base + p + 22))
            let nameLength = Int(u16(d, base + p + 26))
            let extraLength = Int(u16(d, base + p + 28))
            if flags & 0x08 != 0 { break }                       // sizes live after the data: can't walk past it
            let dataStart = p + 30 + nameLength + extraLength
            guard dataStart <= count, dataStart + compressed <= count else { break } // truncated entry: stop
            let name = decodeName(d.subdata(in: (base + p + 30)..<(base + p + 30 + nameLength)), utf8Flag: flags & 0x800 != 0)
            if !name.hasSuffix("/") {
                entries.append(Entry(name: name, method: method, compressedSize: compressed,
                                     uncompressedSize: uncompressed, localOffset: p))
            }
            p = dataStart + compressed
        }
        return entries
    }
}
