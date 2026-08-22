import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// App-private drag payload type (never declared in Info.plist — Apple
    /// supports constructing ephemeral UTTypes in code for exactly this
    /// use: drag-and-drop that only needs to be understood within this
    /// app, not by the system or other apps).
    static let ma3InternalFileRef = UTType(exportedAs: "com.mochizuki.grandmaresourcemanager.internalfileref")
}

/// Identifies a file/folder on a specific configured Source, carried as the
/// drag payload so a row can be dropped onto another Source (including
/// SFTP, which has no real local `URL` to hand Finder-style) without first
/// manually exporting it.
struct InternalFileRef: Codable {
    let sourceID: UUID
    let pathComponents: [String]

    var path: RelativePath { RelativePath(components: pathComponents) }

    init(sourceID: UUID, path: RelativePath) {
        self.sourceID = sourceID
        self.pathComponents = path.components
    }
}

/// What a drop resolved to: either a real file dragged in from Finder, or
/// an in-app reference to a row on another (possibly SFTP) Source.
enum DropPayload {
    case localFile(URL)
    case internalRef(InternalFileRef)
}

/// Inspects dropped `NSItemProvider`s for either representation and
/// resolves them all before calling `completion` on the main queue.
func loadDropPayloads(from providers: [NSItemProvider], completion: @escaping ([DropPayload]) -> Void) {
    let group = DispatchGroup()
    var results: [DropPayload] = []
    let lock = NSLock()

    for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(UTType.ma3InternalFileRef.identifier) {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.ma3InternalFileRef.identifier) { data, _ in
                defer { group.leave() }
                guard let data, let ref = try? JSONDecoder().decode(InternalFileRef.self, from: data) else { return }
                lock.lock(); results.append(.internalRef(ref)); lock.unlock()
            }
        } else {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                if let url {
                    lock.lock(); results.append(.localFile(url)); lock.unlock()
                }
            }
        }
    }

    group.notify(queue: .main) {
        completion(results)
    }
}

/// Builds the `NSItemProvider` for a draggable row: always includes the
/// internal ref (works for any backend, including SFTP), and additionally
/// registers a real file representation when the backend has one on local
/// disk (local/USB), so those rows can still be dragged straight to Finder.
func makeDragProvider(sourceID: UUID, path: RelativePath, localURL: URL?) -> NSItemProvider {
    // `NSItemProvider(object: url as NSURL)` is the correct way to vend a
    // "this represents a file at this URL" representation — it registers
    // the public.file-url object representation via NSURL's
    // NSItemProviderWriting conformance. Using `registerFileRepresentation`
    // with `.fileURL` as the *content type* was a mismatch (that API
    // expects a content-type identifier for the file's actual contents,
    // not "public.file-url" itself) and produced "the specified URL type
    // isn't supported" errors on drop.
    let provider = localURL.map { NSItemProvider(object: $0 as NSURL) } ?? NSItemProvider()

    if let refData = try? JSONEncoder().encode(InternalFileRef(sourceID: sourceID, path: path)) {
        provider.registerDataRepresentation(forTypeIdentifier: UTType.ma3InternalFileRef.identifier, visibility: .all) { completion in
            completion(refData, nil)
            return nil
        }
    }

    return provider
}
