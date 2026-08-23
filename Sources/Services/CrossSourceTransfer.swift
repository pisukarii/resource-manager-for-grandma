import Foundation

/// A local-disk read/copy failing with "no such file" (`NSCocoaErrorDomain`
/// code 4 or 260) almost always means the source file was renamed/removed
/// between when the folder was listed and when the transfer actually ran —
/// common for `gma3_library` content, which the console/onPC may be
/// actively writing to — rather than a bug in how the path was built.
/// Surfacing that explanation (instead of the raw Cocoa error text) tells
/// the user what to actually do about it: refresh and retry.
private func transferErrorMessage(for error: Error) -> String {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain, nsError.code == 4 || nsError.code == 260 {
        return "ファイルが見つかりませんでした。一覧を読み込んだ後にファイルが変更・削除された可能性があります(コンソール/onPC側が同時に書き込んでいる場合など)。一覧を更新してからもう一度お試しください。"
    }
    return error.localizedDescription
}

/// Resolves a dropped payload (a real local file, or an in-app reference to
/// a row on another Source) into a `copyIn` on `targetSource`. For
/// `.internalRef`, this is a two-hop transfer — `copyOut` from the origin
/// Source to a temp file, then `copyIn` into the target — since neither
/// side may be local disk (SFTP -> SFTP included). Drives `transferState`
/// so the UI can show a progress overlay for the (potentially slow, over
/// the console's network link) SFTP legs.
@MainActor
func handleDrop(
    _ payloads: [DropPayload],
    into targetSource: any FileSource,
    at destinationPath: RelativePath,
    store: SourceStore,
    transferState: TransferState
) async {
    for payload in payloads {
        switch payload {
        case .localFile(let url):
            transferState.begin(label: "\(url.lastPathComponent) を \(targetSource.config.name) へコピー中...")
            do {
                try await targetSource.copyIn(from: url, to: destinationPath) { fraction in
                    Task { @MainActor in transferState.progress = fraction }
                }
                transferState.finish()
            } catch {
                transferState.finish(error: transferErrorMessage(for: error))
            }

        case .internalRef(let ref):
            guard ref.sourceID != targetSource.id else { continue } // dropped back onto its own Source
            guard let originSource = store.source(for: ref.sourceID) else { continue }
            await transferBetweenSources(
                origin: originSource,
                path: ref.path,
                target: targetSource,
                destination: destinationPath,
                transferState: transferState
            )
        }
    }
}

@MainActor
private func transferBetweenSources(
    origin: any FileSource,
    path: RelativePath,
    target: any FileSource,
    destination: RelativePath,
    transferState: TransferState
) async {
    let fileName = path.components.last ?? UUID().uuidString
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempURL = tempDir.appendingPathComponent(fileName)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    transferState.begin(label: "\(fileName) を \(origin.config.name) から \(target.config.name) へ転送中...")

    do {
        try await origin.copyOut(from: path, to: tempURL) { fraction in
            Task { @MainActor in transferState.progress = fraction * 0.5 }
        }
        try await target.copyIn(from: tempURL, to: destination) { fraction in
            Task { @MainActor in transferState.progress = 0.5 + fraction * 0.5 }
        }
        transferState.finish()
    } catch {
        transferState.finish(error: transferErrorMessage(for: error))
    }
}
