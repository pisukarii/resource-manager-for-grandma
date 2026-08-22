import SwiftUI

struct FirstRunWelcomeView: View {
    @Environment(SourceStore.self) private var store
    @State private var detected: [MA3LocalDetector.VersionFolder] = []
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("grandMA Resource Manager へようこそ")
                .font(.title2.bold())

            Text("grandMA3 のファイルにすばやくアクセスするための Source を追加してください。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !detected.isEmpty {
                VStack(spacing: 8) {
                    Text("この Mac で検出された onPC:")
                        .font(.callout.bold())
                    ForEach(detected) { folder in
                        Button {
                            let bookmark = BookmarkStore.makeBookmark(for: folder.url)
                            let config = SourceConfig(name: "onPC \(folder.name)", kind: .local, path: folder.url.path, bookmarkData: bookmark)
                            store.addSource(config)
                        } label: {
                            Label("\(folder.name) を追加", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Button("Sourceを追加...") {
                showingAddSheet = true
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            detected = MA3LocalDetector.detectVersionFolders()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSourceSheet()
        }
    }
}
