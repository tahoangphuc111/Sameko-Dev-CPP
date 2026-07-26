import AppKit
import SwiftUI

/// AppKit-backed editor for the native app.  `TextEditor` is intentionally not
/// used here: NSTextView lets us retain selection while applying lightweight
/// C++ highlighting and provides a real line-number gutter.
struct NativeCodeEditor: NSViewRepresentable {
    @Binding var source: String
    @Binding var cursorPosition: String
    let fontSize: CGFloat
    let tabSize: Int
    let wordWrap: Bool
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let accentColor: NSColor
    let onSourceChange: () -> Void
    let onCursorChange: (Int, Int) -> Void
    let requestCompletions: (Int, Int, @escaping @Sendable ([ClangdCompletion]) -> Void) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // NSTextView's default frame is zero.  SwiftUI does not always assign
        // it a usable document size through NSScrollView, leaving a blank code
        // pane even though the model has source text.
        let textView = CompletionTextView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.delegate = context.coordinator
        textView.backgroundColor = backgroundColor
        textView.textColor = foregroundColor
        textView.insertionPointColor = accentColor
        textView.string = source
        textView.requestCompletions = { [weak textView] line, column in
            guard let textView else { return }
            self.requestCompletions(line, column) { values in
                DispatchQueue.main.async { textView.showCompletions(values) }
            }
        }
        configure(textView)
        textView.backgroundColor = backgroundColor
        textView.textColor = foregroundColor
        textView.insertionPointColor = accentColor

        let scroll = NSScrollView()
        scroll.drawsBackground = true
        scroll.backgroundColor = backgroundColor
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = !wordWrap
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = textView
        scroll.verticalRulerView = LineNumberRulerView(textView: textView)
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.applyBaseStyle(textView)
        context.coordinator.updateCursor(textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != source {
            let selection = textView.selectedRange()
            textView.string = source
            textView.setSelectedRange(NSRange(location: min(selection.location, (source as NSString).length), length: 0))
        }
        textView.backgroundColor = backgroundColor
        textView.textColor = foregroundColor
        textView.insertionPointColor = accentColor
        configure(textView)
        context.coordinator.applyBaseStyle(textView)
        if wordWrap {
            textView.frame.size.width = max(1, scroll.contentSize.width)
        }
        scroll.hasHorizontalScroller = !wordWrap
        scroll.verticalRulerView?.needsDisplay = true
    }

    private func configure(_ textView: NSTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let visibleForeground = foregroundColor.usingColorSpace(.deviceRGB) ?? .white
        let visibleBackground = backgroundColor.usingColorSpace(.deviceRGB) ?? .black
        textView.font = font
        textView.drawsBackground = true
        textView.backgroundColor = visibleBackground
        textView.textColor = visibleForeground
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrap
        textView.autoresizingMask = wordWrap ? [.width] : []
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = wordWrap
        textView.textContainer?.containerSize = wordWrap
            ? NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            : NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let tabWidth = font.maximumAdvancement.width * CGFloat(max(1, tabSize))
        let tabs = NSTextTab(textAlignment: .left, location: tabWidth, options: [:])
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.tabStops = [tabs]
            style.defaultTabInterval = tabWidth
            style.lineSpacing = 3
            return style
        }()
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: visibleForeground,
            .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default
        ]
        if textView.frame.width < 1 || textView.frame.height < 1 {
            textView.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeCodeEditor
        private var isApplyingStyle = false

        init(_ parent: NativeCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingStyle, let textView = notification.object as? NSTextView else { return }
            parent.source = textView.string
            parent.onSourceChange()
            applyBaseStyle(textView)
            updateCursor(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView { updateCursor(textView) }
        }

        func updateCursor(_ textView: NSTextView) {
            let range = textView.selectedRange()
            let prefix = (textView.string as NSString).substring(to: min(range.location, (textView.string as NSString).length))
            let line = prefix.reduce(into: 1) { if $1 == "\n" { $0 += 1 } }
            let column = (prefix.lastIndex(of: "\n").map { prefix.distance(from: $0, to: prefix.endIndex) } ?? prefix.count + 1)
            parent.cursorPosition = "Ln \(line), Col \(column)"
            parent.onCursorChange(line - 1, column - 1)
        }

        /// Syntax attribute replacement caused NSTextView on macOS 26/Xcode 27
        /// to stop drawing every glyph shortly after its first update. Keep a
        /// stable foreground attribute; syntax colors can return once the
        /// AppKit regression is resolved.
        func applyBaseStyle(_ textView: NSTextView) {
            guard !isApplyingStyle else { return }
            isApplyingStyle = true
            defer { isApplyingStyle = false }
            let range = NSRange(location: 0, length: (textView.string as NSString).length)
            guard range.length > 0, let storage = textView.textStorage else { return }
            storage.addAttribute(.foregroundColor, value: parent.foregroundColor.usingColorSpace(.deviceRGB) ?? .white, range: range)
            textView.needsDisplay = true
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
    }
}

private final class CompletionTextView: NSTextView {
    var requestCompletions: ((Int, Int) -> Void)?
    private var completionRange = NSRange(location: 0, length: 0)

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control,
           event.charactersIgnoringModifiers == " " {
            requestCompletion()
            return
        }
        super.keyDown(with: event)
    }

    private func requestCompletion() {
        let cursor = selectedRange().location
        let text = string as NSString
        let prefix = text.substring(to: min(cursor, text.length))
        let line = prefix.filter { $0 == "\n" }.count
        let column = prefix.lastIndex(of: "\n").map { prefix.distance(from: $0, to: prefix.endIndex) - 1 } ?? prefix.count
        var start = cursor
        while start > 0 {
            let scalar = text.substring(with: NSRange(location: start - 1, length: 1)).unicodeScalars.first
            guard let scalar, CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_:")).contains(scalar) else { break }
            start -= 1
        }
        completionRange = NSRange(location: start, length: cursor - start)
        requestCompletions?(line, column)
    }

    func showCompletions(_ values: [ClangdCompletion]) {
        guard !values.isEmpty, window != nil else { return }
        let menu = NSMenu()
        for item in values.prefix(30) {
            let choice = NSMenuItem(title: item.label, action: #selector(insertCompletion(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = item
            menu.addItem(choice)
        }
        let caret = firstRect(forCharacterRange: selectedRange(), actualRange: nil)
        let windowPoint = window?.convertPoint(fromScreen: caret.origin) ?? .zero
        let origin = convert(windowPoint, from: nil)
        menu.popUp(positioning: nil, at: NSPoint(x: origin.x, y: origin.y - 4), in: self)
    }

    @objc private func insertCompletion(_ sender: NSMenuItem) {
        guard let completion = sender.representedObject as? ClangdCompletion else { return }
        shouldChangeText(in: completionRange, replacementString: completion.insertText)
        textStorage?.replaceCharacters(in: completionRange, with: completion.insertText)
        didChangeText()
        setSelectedRange(NSRange(location: completionRange.location + (completion.insertText as NSString).length, length: 0))
    }
}

private final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 42
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layout = textView.layoutManager, let container = textView.textContainer else { return }
        NSColor.controlBackgroundColor.setFill(); rect.fill()
        let visible = textView.enclosingScrollView?.contentView.bounds ?? .zero
        let glyphRange = layout.glyphRange(forBoundingRect: visible, in: container)
        let string = textView.string as NSString
        var index = layout.characterIndexForGlyph(at: glyphRange.location)
        var line = string.substring(to: min(index, string.length)).filter { $0 == "\n" }.count + 1
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
        while index < NSMaxRange(glyphRange) {
            let lineRange = string.lineRange(for: NSRange(location: index, length: 0))
            let glyph = layout.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var lineRect = layout.lineFragmentRect(forGlyphAt: glyph.location, effectiveRange: nil)
            lineRect.origin.y += textView.textContainerOrigin.y
            let value = "\(line)" as NSString
            value.draw(at: NSPoint(x: ruleThickness - value.size(withAttributes: attributes).width - 8, y: lineRect.minY + 2), withAttributes: attributes)
            index = NSMaxRange(lineRange)
            line += 1
        }
    }
}
