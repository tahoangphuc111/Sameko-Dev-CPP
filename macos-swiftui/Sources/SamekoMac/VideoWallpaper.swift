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
    private weak var observedWindow: NSWindow?

    /// `Bundle.module` traps if a SwiftPM executable is copied on its own.
    /// CI used to publish exactly that file, so locate a sidecar bundle only
    /// when it actually exists and otherwise fall back without crashing.
    private static let sidecarResourceBundle: Bundle? = {
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
        let candidates = [
            executableDirectory?.appendingPathComponent("SamekoMac_SamekoMac.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("SamekoMac_SamekoMac.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/SamekoMac_SamekoMac.bundle")
        ]
        return candidates.compactMap { $0 }.compactMap { Bundle(path: $0.path) }.first
    }()

    init(resourceName: String) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        webView.navigationDelegate = self
        wantsLayer = true
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
        play(resourceName: resourceName)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        center.removeObserver(self)
        observedWindow = window
        center.addObserver(self, selector: #selector(updatePlaybackState(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(updatePlaybackState(_:)), name: NSApplication.didResignActiveNotification, object: nil)
        if let window {
            center.addObserver(self, selector: #selector(updatePlaybackState(_:)), name: NSWindow.didChangeOcclusionStateNotification, object: window)
            center.addObserver(self, selector: #selector(updatePlaybackState(_:)), name: NSWindow.didMiniaturizeNotification, object: window)
            center.addObserver(self, selector: #selector(updatePlaybackState(_:)), name: NSWindow.didDeminiaturizeNotification, object: window)
        }
        updatePlayback()
    }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }

    func play(resourceName: String) {
        guard currentResource != resourceName else { return }
        currentResource = resourceName
        guard let url = Self.sidecarResourceBundle?.url(forResource: resourceName, withExtension: "webm", subdirectory: "Resources/backgrounds")
                ?? Self.sidecarResourceBundle?.url(forResource: resourceName, withExtension: "webm", subdirectory: "backgrounds")
                ?? Bundle.main.url(forResource: resourceName, withExtension: "webm", subdirectory: "backgrounds") else { return }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body,video{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}video{object-fit:cover}</style>
        </head><body><video autoplay muted loop playsinline><source src="\(url.lastPathComponent)" type="video/webm"></video></body></html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    @objc private func updatePlaybackState(_ notification: Notification) { updatePlayback() }

    private func updatePlayback() {
        let visible = observedWindow?.occlusionState.contains(.visible) == true
        let shouldPlay = NSApplication.shared.isActive && visible && observedWindow?.isMiniaturized == false
        let script = shouldPlay
            ? "document.querySelector('video')?.play().catch(() => {})"
            : "document.querySelector('video')?.pause()"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    deinit { NotificationCenter.default.removeObserver(self) }
}

extension VideoWallpaperView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { updatePlayback() }
}
