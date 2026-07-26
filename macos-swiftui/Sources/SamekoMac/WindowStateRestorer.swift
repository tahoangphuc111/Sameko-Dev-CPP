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
    private var titleAccessory: NSTitlebarAccessoryViewController?
    private weak var titleLabel: NSTextField?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, watchedWindow == nil else { return }
        watchedWindow = window
        applyTitlebarStyle(to: window)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            self?.applyTitlebarStyle(to: window)
        }
        if let savedFrame = WindowFrameStore.frame { window.setFrame(savedFrame, display: true) }
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            center.addObserver(self, selector: #selector(saveWindowFrame(_:)), name: name, object: window)
        }
        center.addObserver(self, selector: #selector(refreshTitlebar(_:)), name: NSWindow.didBecomeMainNotification, object: window)
    }

    /// The system title field can ignore a late appearance change in the
    /// unified SwiftUI title bar. Hide it and install a native white title so
    /// the label remains legible on every macOS appearance.
    private func applyTitlebarStyle(to window: NSWindow) {
        if window.appearance?.name != .darkAqua {
            window.appearance = NSAppearance(named: .darkAqua)
        }
        window.titleVisibility = .hidden
        if titleAccessory == nil {
            let label = NSTextField(labelWithString: window.title)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .white
            label.lineBreakMode = .byTruncatingTail

            let container = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])

            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .left
            accessory.view = container
            window.addTitlebarAccessoryViewController(accessory)
            titleAccessory = accessory
            titleLabel = label
        }
        if titleLabel?.stringValue != window.title { titleLabel?.stringValue = window.title }
        if titleLabel?.textColor != .white { titleLabel?.textColor = .white }
    }

    @objc private func refreshTitlebar(_ notification: Notification) {
        if let window = notification.object as? NSWindow { applyTitlebarStyle(to: window) }
    }

    @objc private func saveWindowFrame(_ notification: Notification) {
        if let window = notification.object as? NSWindow { WindowFrameStore.save(window.frame) }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
