import SwiftUI
import AppKit
import AVKit
import WebKit

/// Plays a video in the inspector pane. mp4/m4v/mov use AVPlayer; WebM isn't
/// supported by AVFoundation ("Cannot Open"), so it plays in WebKit, which
/// decodes VP8/VP9.
struct VideoPreviewView: View {
    let url: URL

    static func usesWebKit(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "webm"
    }

    var body: some View {
        Group {
            if Self.usesWebKit(url) {
                WebVideoView(url: url)
            } else {
                AVVideoView(url: url)
            }
        }
        .id(url)   // a different file gets a fresh player
    }
}

private struct AVVideoView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        view.player = AVPlayer(url: url)      // paused on the first frame
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

/// WebM via a `<video>` element. The page is a small temp HTML file given
/// read access to the file system, because WebKit refuses to load a local
/// video from `loadHTMLString` and shows a bare file load as a download.
private struct WebVideoView: NSViewRepresentable {
    let url: URL

    final class Coordinator { var page: URL? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.setValue(false, forKey: "drawsBackground")
        let source = url.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "%22")
        let html = """
        <html><body style="margin:0;background:#000;height:100vh;display:flex;align-items:center;justify-content:center">
        <video src="\(source)" controls loop style="max-width:100%;max-height:100%"></video>
        </body></html>
        """
        let page = FileManager.default.temporaryDirectory.appendingPathComponent("webm-preview-\(UUID().uuidString).html")
        try? html.write(to: page, atomically: true, encoding: .utf8)
        context.coordinator.page = page
        web.loadFileURL(page, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        return web
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.evaluateJavaScript("document.querySelector('video')?.pause()")
        nsView.loadHTMLString("", baseURL: nil)
        if let page = coordinator.page { try? FileManager.default.removeItem(at: page) }
    }
}
