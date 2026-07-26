import AppKit
import SwiftUI
import WebKit

/// WebKit is intentional: the original assets are VP9/WebM, which AVPlayer
/// cannot decode on macOS. Safari/WebKit can, so this keeps the shared theme
/// videos working in development and in the app bundle.
struct VideoWallpaper: NSViewRepresentable {
    let resourceName: String

    func makeNSView(context: Context) -> VideoWallpaperView {
        VideoWallpaperView(resourceName: resourceName)
    }

    func updateNSView(_ view: VideoWallpaperView, context: Context) {
        view.play(resourceName: resourceName)
    }
}

@MainActor
final class VideoWallpaperView: NSView {
    private let webView: WKWebView
    private var currentResource: String?

    init(resourceName: String) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        wantsLayer = true
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
        play(resourceName: resourceName)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }

    func play(resourceName: String) {
        guard currentResource != resourceName else { return }
        currentResource = resourceName
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "webm", subdirectory: "Resources/backgrounds")
                ?? Bundle.main.url(forResource: resourceName, withExtension: "webm", subdirectory: "backgrounds") else { return }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body,video{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}video{object-fit:cover}</style>
        </head><body><video autoplay muted loop playsinline><source src="\(url.lastPathComponent)" type="video/webm"></video></body></html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
