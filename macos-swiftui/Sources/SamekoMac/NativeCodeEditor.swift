import AppKit
import SwiftUI

/// AppKit-backed editor for the native app.  `TextEditor` is intentionally not
/// used here: NSTextView lets us retain selection and provides a real
/// line-number gutter.
struct NativeCodeEditor: NSViewRepresentable {
    @Binding var source: String
    @Binding var cursorPosition: String
    let fontSize: CGFloat
    let fontName: String
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
        // Opt into TextKit 2 and never touch `layoutManager`. Reading that
        // legacy property forces NSTextView into NSLayoutManager compatibility
        // mode after its first frame; on macOS 26 that transition preserved the
        // string and line fragments but stopped drawing every source glyph.
        let textView = CompletionTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.delegate = context.coordinator
        textView.requestCompletions = { [weak textView] (line: Int, column: Int) in
            guard let textView else { return }
            self.requestCompletions(line, column) { values in
                DispatchQueue.main.async { textView.showCompletions(values) }
            }
        }
        configure(textView)
        // Assign a fully styled source before attaching the text view to its
        // scroll view. This keeps both the backing string and glyph attributes
        // stable across the first SwiftUI update.
        textView.textStorage?.setAttributedString(NSAttributedString(string: source, attributes: textView.typingAttributes))
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        let scroll = NSScrollView()
        scroll.drawsBackground = true
        scroll.backgroundColor = backgroundColor
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = !wordWrap
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = textView
        let ruler = LineNumberRulerView(textView: textView)
        ruler.updateLineCount(for: source)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.updateCursor(textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != source {
            let selection = textView.selectedRange()
            let styledSource = NSAttributedString(string: source, attributes: textView.typingAttributes)
            textView.textStorage?.setAttributedString(styledSource)
            textView.setSelectedRange(NSRange(location: min(selection.location, (source as NSString).length), length: 0))
            context.coordinator.rebuildLineIndex(for: source)
            (scroll.verticalRulerView as? LineNumberRulerView)?.updateLineCount(for: source)
        }
    }

    private func configure(_ textView: NSTextView) {
        let requestedFont = fontName == WorkspaceModel.systemEditorFontID ? nil : NSFont(name: fontName, size: fontSize)
        let font = requestedFont?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true
            ? requestedFont!
            : NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
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
            ? NSSize(width: max(1, textView.bounds.width), height: CGFloat.greatestFiniteMagnitude)
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
        private var indexedSource = ""
        private var lineStarts = [0]

        init(_ parent: NativeCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.source = textView.string
            parent.onSourceChange()
            rebuildLineIndex(for: textView.string)
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.updateLineCount(for: textView.string)
            updateCursor(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView { updateCursor(textView) }
        }

        func updateCursor(_ textView: NSTextView) {
            rebuildLineIndex(for: textView.string)
            let location = min(textView.selectedRange().location, (textView.string as NSString).length)
            var lower = 0
            var upper = lineStarts.count
            while lower < upper {
                let middle = (lower + upper) / 2
                if lineStarts[middle] <= location { lower = middle + 1 } else { upper = middle }
            }
            let lineIndex = max(0, lower - 1)
            let column = location - lineStarts[lineIndex] + 1
            parent.cursorPosition = "Ln \(lineIndex + 1), Col \(column)"
            parent.onCursorChange(lineIndex, column - 1)
        }

        func rebuildLineIndex(for source: String) {
            guard source != indexedSource else { return }
            indexedSource = source
            lineStarts = [0]
            for (offset, codeUnit) in source.utf16.enumerated() where codeUnit == 10 {
                lineStarts.append(offset + 1)
            }
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
    private var lineCount = 1

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 42
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateLineCount(for source: String) {
        let newCount = max(1, source.utf16.reduce(into: 1) { if $1 == 10 { $0 += 1 } })
        guard newCount != lineCount else { return }
        lineCount = newCount
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let font = textView.font else { return }
        NSColor.controlBackgroundColor.setFill(); rect.fill()
        let visible = textView.enclosingScrollView?.contentView.bounds ?? .zero
        let lineHeight = ceil(font.ascender - font.descender + font.leading + 3)
        let topInset = textView.textContainerInset.height
        let firstLine = max(0, Int(floor((visible.minY - topInset) / lineHeight)))
        let lastLine = min(lineCount - 1, Int(ceil((visible.maxY - topInset) / lineHeight)))
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
        guard firstLine <= lastLine else { return }
        for lineIndex in firstLine...lastLine {
            let value = "\(lineIndex + 1)" as NSString
            let y = topInset + CGFloat(lineIndex) * lineHeight + 2
            value.draw(at: NSPoint(x: ruleThickness - value.size(withAttributes: attributes).width - 8, y: y), withAttributes: attributes)
        }
    }
}
