import SwiftUI

struct SFTPConnectionForm: View {
    @Environment(SourceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum ConnectionTarget: String, CaseIterable {
        case console = "実機コンソール"
        case otherOnPC = "他のonPC (SSH)"

        var defaultUsername: String {
            switch self {
            case .console: return "remote"
            case .otherOnPC: return ""
            }
        }

        var hostHint: String {
            switch self {
            case .console: return "ホスト (Manetアダプタの IPアドレス)"
            case .otherOnPC: return "ホスト (そのMac/PCの IPアドレス)"
            }
        }

        var usernameHint: String {
            switch self {
            case .console: return "コンソールのSFTPアカウント (通常 remote)"
            case .otherOnPC: return "そのMac/PCのログインユーザー名"
            }
        }

        /// Default base path to pre-fill when switching to this target.
        /// `.console` uses `/MALighting/grandma3` — the console's internal
        /// storage path, confirmed 2026-08-19 (Linux console filesystem;
        /// USB inserted into the console itself would be
        /// `/media/<USB名>/gma3_library/`, not used here). `.otherOnPC` is
        /// left blank since it depends on that machine's own username/version.
        var defaultBasePath: String {
            switch self {
            case .console: return "/MALighting/grandma3"
            case .otherOnPC: return ""
            }
        }

        var basePathPlaceholder: String {
            switch self {
            case .console: return "例: /MALighting/grandma3"
            case .otherOnPC: return "例(Mac): /Users/ユーザー名/MALightingTechnology/gma3_2.4.2"
            }
        }

        var basePathHelpText: String {
            switch self {
            case .console:
                return "実機コンソール(Linux)の内部ストレージ上のパスです。バージョンやモデルによって異なる場合は、ここを実際のパスに書き換えてから「接続をテスト」してください。"
            case .otherOnPC:
                return "そのMac/PC上の onPC インストールフォルダを指定してください。\nMac: /Users/ユーザー名/MALightingTechnology/gma3_x.y.z\nWindows: C:/ProgramData/MALightingTechnology/gma3_x.y.z (バージョン番号は実際にインストールされているものに置き換えてください)"
            }
        }
    }

    /// When editing an already-configured SFTP Source (vs. adding a new
    /// one), its id/name/host/etc. are pre-filled and saving updates it in
    /// place instead of creating a new Source.
    let existingConfig: SourceConfig?

    @State private var connectionTarget: ConnectionTarget = .console
    @State private var name = "コンソール"
    @State private var host = ""
    @State private var port = "22"
    @State private var username = "remote"
    @State private var password = ""
    @State private var basePathOverride = ConnectionTarget.console.defaultBasePath

    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showingHelp = false
    @State private var showingOnPCSetupInstructions = false
    @State private var isDiscovering = false
    @State private var discoveredPaths: [String]?

    private enum TestResult {
        case success
        case failure(String)
    }

    init(existingConfig: SourceConfig? = nil) {
        self.existingConfig = existingConfig
        if let existingConfig {
            _name = State(initialValue: existingConfig.name)
            _host = State(initialValue: existingConfig.host ?? "")
            _port = State(initialValue: String(existingConfig.port ?? 22))
            _username = State(initialValue: existingConfig.username ?? "")
            _password = State(initialValue: KeychainCredentialStore.password(for: existingConfig.id) ?? "")
            _basePathOverride = State(initialValue: existingConfig.basePathOverride ?? "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepsCard

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("接続先").font(.callout.weight(.medium))
                    Picker("", selection: $connectionTarget) {
                        ForEach(ConnectionTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: connectionTarget) { _, newTarget in
                        // このMacの/コンソールのログイン情報が混ざらないよう、
                        // 切り替えたら想定される既定値に揃える。
                        // 編集時は既存の入力値を誤って消さないようスキップ。
                        guard existingConfig == nil else { return }
                        username = newTarget.defaultUsername
                        name = newTarget == .console ? "コンソール" : "onPC (SSH)"
                        basePathOverride = newTarget.defaultBasePath
                    }
                    Text("実機コンソールとonPC機ではログイン情報が別物です。混ざらないよう、まずどちらに繋ぐか選んでください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if connectionTarget == .otherOnPC {
                        Button {
                            showingOnPCSetupInstructions = true
                        } label: {
                            Label("初回設定方法", systemImage: "questionmark.circle")
                        }
                        .buttonStyle(.link)
                    }
                }

                labeledField("表示名", text: $name)
                labeledField(connectionTarget.hostHint, text: $host, placeholder: "例: 10.0.1.50")
                HStack(spacing: 10) {
                    labeledField("ポート", text: $port)
                        .frame(width: 100)
                    labeledField("ユーザー名", text: $username, placeholder: connectionTarget.usernameHint)
                }
                labeledSecureField("パスワード", text: $password)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("ベースパス")
                            .font(.callout.weight(.medium))
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showingHelp.toggle() }
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField(connectionTarget.basePathPlaceholder, text: $basePathOverride)
                        .textFieldStyle(.roundedBorder)
                    if showingHelp {
                        Text(connectionTarget.basePathHelpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if connectionTarget == .otherOnPC {
                        discoveryControls
                    }
                }
            }

            resultBanner

            HStack {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.circle")
                        }
                        Text("接続をテスト")
                    }
                }
                .disabled(host.isEmpty || isTesting)

                Spacer()

                Button(existingConfig == nil ? "追加" : "保存") {
                    addSource()
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty)
            }
        }
        .sheet(isPresented: $showingOnPCSetupInstructions) {
            OnPCSSHSetupInstructionsView()
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("接続手順", systemImage: "list.number")
                .font(.callout.weight(.semibold))
            stepRow(1, "コンソール(またはSSH/SFTPを有効化したonPC機)のIPアドレスを確認")
            stepRow(2, "下にホスト・ユーザー名・パスワードを入力")
            stepRow(3, "「接続をテスト」で疎通確認 → 成功したら「追加」")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor.opacity(0.25)))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.callout.weight(.medium))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func labeledSecureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.callout.weight(.medium))
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var resultBanner: some View {
        if let testResult {
            HStack(spacing: 6) {
                switch testResult {
                case .success:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("接続に成功しました")
                case .failure(let message):
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text(message).lineLimit(2)
                }
            }
            .font(.callout)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (isSuccess(testResult) ? Color.green : Color.red).opacity(0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func isSuccess(_ result: TestResult) -> Bool {
        if case .success = result { return true }
        return false
    }

    private func makeConfig(id: UUID = UUID()) -> SourceConfig {
        SourceConfig(
            id: id,
            name: name.isEmpty ? host : name,
            kind: .sftp,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            basePathOverride: basePathOverride.isEmpty ? nil : basePathOverride
        )
    }

    @ViewBuilder
    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await runDiscovery() }
            } label: {
                HStack(spacing: 6) {
                    if isDiscovering {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text("ベースパスを自動検出")
                }
            }
            .disabled(host.isEmpty || username.isEmpty || password.isEmpty || isDiscovering)

            if let discoveredPaths {
                if discoveredPaths.isEmpty {
                    Text("見つかりませんでした。手動で入力してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("見つかった候補:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(discoveredPaths, id: \.self) { path in
                        Button(path) {
                            basePathOverride = path
                            self.discoveredPaths = nil
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func runDiscovery() async {
        isDiscovering = true
        discoveredPaths = nil
        let probeConfig = makeConfig()
        KeychainCredentialStore.savePassword(password, for: probeConfig.id)
        let probe = ConsoleSFTPSource(config: probeConfig)
        do {
            try await probe.connect()
            discoveredPaths = await probe.discoverOnPCVersionFolders(usernameHint: username)
        } catch {
            discoveredPaths = []
        }
        KeychainCredentialStore.deletePassword(for: probeConfig.id)
        isDiscovering = false
    }

    private func testConnection() async {
        isTesting = true
        withAnimation { testResult = nil }
        let config = makeConfig()
        KeychainCredentialStore.savePassword(password, for: config.id)
        let probe = ConsoleSFTPSource(config: config)
        do {
            try await probe.connect()
            withAnimation { testResult = .success }
        } catch {
            withAnimation { testResult = .failure(error.localizedDescription) }
        }
        KeychainCredentialStore.deletePassword(for: config.id)
        isTesting = false
    }

    private func addSource() {
        let config = makeConfig(id: existingConfig?.id ?? UUID())
        KeychainCredentialStore.savePassword(password, for: config.id)
        if existingConfig != nil {
            store.updateSource(config)
        } else {
            store.addSource(config)
        }
        dismiss()
    }
}
