import Foundation
import Observation

/// Drives the app-wide transfer progress overlay shown while a cross-Source
/// drag (Source A -> Source B, including SFTP on either end) is running a
/// copyOut-then-copyIn under the hood. `@unchecked Sendable` because
/// progress callbacks arrive from background transfer code (SFTP chunked
/// read/write) — every mutation is re-hopped onto MainActor via `Task`
/// before touching `self`, so this is safe despite not being actor-isolated
/// at the type-system level for those call sites.
@MainActor
@Observable
final class TransferState: @unchecked Sendable {
    var isActive = false
    var progress: Double = 0
    var label = ""
    var errorMessage: String?

    /// Bumped every time a transfer finishes (success or failure). Views
    /// showing a folder listing observe this (alongside the current path)
    /// to refresh themselves afterward — a Source's file list can otherwise
    /// go stale mid-transfer if the origin file was changed/removed
    /// (e.g. `gma3_library` content, which the console/onPC may be actively
    /// writing) between when the list was loaded and when the transfer ran.
    private(set) var completedCount = 0

    func begin(label: String) {
        self.label = label
        self.progress = 0
        self.isActive = true
        self.errorMessage = nil
    }

    func finish(error: String? = nil) {
        isActive = false
        errorMessage = error
        completedCount += 1
    }
}
