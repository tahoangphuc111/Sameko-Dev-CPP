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
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, observers.isEmpty else { return }
        if let savedFrame = WindowFrameStore.frame { window.setFrame(savedFrame, display: true) }
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            observers.append(center.addObserver(forName: name, object: window, queue: .main) { notification in
                if let window = notification.object as? NSWindow { WindowFrameStore.save(window.frame) }
            })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
