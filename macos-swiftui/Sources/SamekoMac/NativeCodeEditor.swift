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
        let textView = CompletionTextView()
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
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = !wordWrap
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = textView
        scroll.verticalRulerView = LineNumberRulerView(textView: textView)
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.highlight(textView)
        context.coordinator.updateCursor(textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != source {
            let selection = textView.selectedRange()
            textView.string = source
            textView.setSelectedRange(NSRange(location: min(selection.location, (source as NSString).length), length: 0))
            context.coordinator.highlight(textView)
        }
        configure(textView)
        scroll.hasHorizontalScroller = !wordWrap
        scroll.verticalRulerView?.needsDisplay = true
    }

    private func configure(_ textView: NSTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrap
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
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeCodeEditor
        private var isHighlighting = false

        init(_ parent: NativeCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isHighlighting, let textView = notification.object as? NSTextView else { return }
            parent.source = textView.string
            parent.onSourceChange()
            highlight(textView)
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

        func highlight(_ textView: NSTextView) {
            guard !isHighlighting else { return }
            isHighlighting = true
            defer { isHighlighting = false }
            let text = textView.string as NSString
            let range = NSRange(location: 0, length: text.length)
            let selection = textView.selectedRange()
            let storage = textView.textStorage!
            storage.beginEditing()
            storage.setAttributes([
                .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: textView.textColor ?? NSColor.labelColor,
                .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default
            ], range: range)
            apply("//.*|/\\*[\\s\\S]*?\\*/", color: .systemGreen, in: storage, range: range)
            apply("\\\"(?:\\\\.|[^\\\"])*\\\"|'(?:\\\\.|[^'])*'", color: .systemOrange, in: storage, range: range)
            apply("\\b(?:alignas|auto|bool|break|case|catch|char|class|const|constexpr|continue|default|delete|do|double|else|enum|explicit|export|false|float|for|friend|if|inline|int|long|namespace|new|noexcept|nullptr|operator|private|protected|public|return|short|signed|sizeof|static|struct|switch|template|this|throw|true|try|typedef|typename|union|unsigned|using|virtual|void|volatile|while)\\b", color: .systemPurple, in: storage, range: range)
            apply("#[[:space:]]*(?:include|define|if|ifdef|ifndef|endif|pragma)", color: .systemPink, in: storage, range: range)
            storage.endEditing()
            textView.setSelectedRange(selection)
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        private func apply(_ pattern: String, color: NSColor, in storage: NSTextStorage, range: NSRange) {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return }
            expression.enumerateMatches(in: storage.string, range: range) { match, _, _ in
                if let range = match?.range { storage.addAttribute(.foregroundColor, value: color, range: range) }
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
