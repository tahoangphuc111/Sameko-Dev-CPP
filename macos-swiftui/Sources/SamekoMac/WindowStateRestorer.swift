import AppKit
import SwiftUI

private enum WindowFrameStore {
    private static let key = "mainWindowFrame"

    static var frame: NSRect? {
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        let frame = NSRectFromString(value)
        guard frame.width >= 640, frame.height >= 480,
              NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) else { return nil }
        return frame
    }

    static func save(_ frame: NSRect) { UserDefaults.standard.set(NSStringFromRect(frame), forKey: key) }
}

/// Invisible view that connects SwiftUI's WindowGroup to native frame restore.
struct WindowStateRestorer: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowStateView { WindowStateView() }
    func updateNSView(_ view: WindowStateView, context: Context) {}
}

final class WindowStateView: NSView {
    private weak var watchedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, watchedWindow == nil else { return }
        watchedWindow = window
        if let savedFrame = WindowFrameStore.frame { window.setFrame(savedFrame, display: true) }
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            center.addObserver(self, selector: #selector(saveWindowFrame(_:)), name: name, object: window)
        }
    }

    @objc private func saveWindowFrame(_ notification: Notification) {
        if let window = notification.object as? NSWindow { WindowFrameStore.save(window.frame) }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
