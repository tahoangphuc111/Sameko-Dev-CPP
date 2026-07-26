import AVFoundation
import AppKit
import SwiftUI

/// Plays the original Electron theme videos when Sameko is launched from its
/// app bundle. Development builds gracefully fall back to the animated SwiftUI
/// background when those resources have not been copied yet.
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
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var currentResource: String?

    init(resourceName: String) {
        super.init(frame: .zero)
        wantsLayer = true
        play(resourceName: resourceName)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    func play(resourceName: String) {
        guard currentResource != resourceName else { return }
        currentResource = resourceName
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "webm", subdirectory: "backgrounds") else { return }
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        self.playerLayer?.removeFromSuperlayer()
        self.player = player
        self.playerLayer = layer
        self.layer?.addSublayer(layer)
        layer.frame = bounds
        NotificationCenter.default.addObserver(self, selector: #selector(loopVideo(_:)), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        player.play()
    }

    @objc private func loopVideo(_ notification: Notification) {
        player?.seek(to: .zero)
        player?.play()
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
