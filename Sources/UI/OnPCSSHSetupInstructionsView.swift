import SwiftUI

/// Walks the user through enabling SSH/SFTP on another Mac or Windows PC so
/// its onPC install can be reached as a "他のonPC (SSH)" Source. Shown from
/// `SFTPConnectionForm` since this is the step most likely to trip people
/// up — the credentials here are the machine's own OS login, not anything
/// grandMA-specific, which is easy to mix up with the console's account.
struct OnPCSSHSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("onPC機への初回設定方法")
                    .font(.title3.bold())
                Spacer()
                Button("閉じる") { dismiss() }
            }

            Text("別のMac/PCで動いているgrandMA3 onPCにネットワーク経由でアクセスするには、そのMac/PC自体のSSHログインを有効にする必要があります。ここで使うユーザー名・パスワードは実機コンソールのものとは別の、そのMac/PC自体のOSログイン情報です。")
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    platformSection(
                        title: "Mac の場合",
                        symbol: "laptopcomputer",
                        steps: [
                            "そのMacで「システム設定」→「一般」→「共有」を開く",
                            "「リモートログイン」をオンにする",
                            "画面に表示されるユーザー名とアドレス(例: you@192.168.x.x)を控える",
                            "このアプリのSFTPフォームに、そのMacのIPアドレス・ログインユーザー名・ログインパスワードを入力"
                        ]
                    )

                    platformSection(
                        title: "Windows の場合",
                        symbol: "pc",
                        steps: [
                            "「設定」→「アプリ」→「オプション機能」を開き、「OpenSSH サーバー」を追加",
                            "「サービス」アプリ(services.msc)で「OpenSSH SSH Server」を探し、右クリック→「開始」。次回以降も自動起動させるならスタートアップの種類を「自動」に変更",
                            "必要であればWindowsファイアウォールでポート22の受信を許可",
                            "このアプリのSFTPフォームに、そのPCのIPアドレス・Windowsのログインユーザー名・ログインパスワードを入力"
                        ]
                    )
                }
                .padding(.vertical, 4)
            }

            Text("いずれの場合も、ベースパスにはそのMac/PC上のonPCインストールフォルダ(Mac: ~/MALightingTechnology/gma3_x.y.z、Windows: C:\\ProgramData\\MALightingTechnology\\gma3_x.y.z)を指定してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 480, height: 480)
    }

    private func platformSection(title: String, symbol: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.accentColor.opacity(0.25)))
                    Text(step)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
