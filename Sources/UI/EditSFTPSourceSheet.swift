import SwiftUI

/// Standalone wrapper around `SFTPConnectionForm` for editing an existing
/// SFTP Source's login info/IP/base path from the sidebar's "接続設定を編集..."
/// menu — `AddSourceSheet` only covers the initial-add flow.
struct EditSFTPSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existingConfig: SourceConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("接続設定を編集")
                .font(.title3.bold())
            SFTPConnectionForm(existingConfig: existingConfig)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 480, height: 660)
    }
}
