import AppKit
import SkywriteCore

extension NSAttributedString.Key {
    /// Marks the `#` of a heading while they're hidden; the layout manager gives those characters no glyphs.
    static let hiddenMarkdown = NSAttributedString.Key("SkywriteHiddenMarkdown")
}

/// Headings typed with `#`, `##` and `###`, and when their marks show.
///
/// The marks stay hidden except on the line the caret is on (or the lines a selection touches) while you type, the way
/// Obsidian's Live Preview and Bear's Hide Markdown work. A locked note shows none.
extension NoteController: NSLayoutManagerDelegate {
    func textAttributes(font: NSFont, color: NSColor = .white) -> [NSAttributedString.Key: Any] {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        return [.font: font, .foregroundColor: color, .shadow: shadow]
    }

    /// The `#` you can see while typing are drawn in Apple's secondary label colour for Dark Mode, the way the glass is.
    private var markColor: NSColor {
        var color = NSColor.white
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            color = NSColor.secondaryLabelColor.usingColorSpace(.sRGB) ?? color
        }
        return color
    }

    /// Styles every cell: headings larger, their marks hidden or dimmed. Called before each measurement.
    func applyTextAttributes() {
        let body = textAttributes(font: style.font(zoom: zoom))
        let markColor = markColor
        for cell in cellViews {
            let string = cell.string as NSString
            let isTyping = isEditing && panel.firstResponder === cell
            let revealed = isTyping ? string.lineRange(for: cell.selectedRange()) : nil
            cell.revealedLines = revealed
            let headings = NoteMarkdown.headings(in: cell.string)
            let caretHeading = isTyping ? headings.first { NSLocationInRange(cell.selectedRange().location, $0.lineRange) || cell.selectedRange().location == NSMaxRange($0.lineRange) } : nil
            cell.typingAttributes = caretHeading.map { textAttributes(font: style.headingFont(level: $0.level, zoom: zoom)) } ?? body
            guard let storage = cell.textStorage, storage.length > 0 else {
                cell.listMarkers = []
                continue
            }
            storage.beginEditing()
            storage.setAttributes(body, range: NSRange(location: 0, length: storage.length))
            for heading in headings {
                let font = style.headingFont(level: heading.level, zoom: zoom)
                storage.setAttributes(textAttributes(font: font), range: heading.lineRange)
                let isRevealed = revealed.map { NSIntersectionRange($0, heading.lineRange).length > 0 || NSLocationInRange(heading.lineRange.location, $0) } ?? false
                if isRevealed {
                    storage.addAttribute(.foregroundColor, value: markColor, range: heading.markerRange)
                } else {
                    storage.addAttribute(.hiddenMarkdown, value: true, range: heading.markerRange)
                }
            }
            styleLists(in: cell, storage: storage)
            storage.endEditing()
            cell.layoutManager?.invalidateGlyphs(forCharacterRange: NSRange(location: 0, length: storage.length), changeInLength: 0, actualCharacterRange: nil)
        }
    }

    /// Characters marked hidden get no glyph, so they take no room and the text closes up around them.
    func layoutManager( // swiftlint:disable:this function_parameter_count - AppKit's own delegate method
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let storage = layoutManager.textStorage else { return 0 }
        var changed = [NSLayoutManager.GlyphProperty](unsafeUninitializedCapacity: glyphRange.length) { buffer, count in
            for index in 0..<glyphRange.length {
                buffer[index] = properties[index]
            }
            count = glyphRange.length
        }
        var hidesAny = false
        for index in 0..<glyphRange.length where storage.attribute(.hiddenMarkdown, at: characterIndexes[index], effectiveRange: nil) != nil {
            changed[index] = .null
            hidesAny = true
        }
        guard hidesAny else { return 0 }
        layoutManager.setGlyphs(glyphs, properties: changed, characterIndexes: characterIndexes, font: font, forGlyphRange: glyphRange)
        return glyphRange.length
    }

    /// Moving the caret to another line shows that line's `#` and hides the last one's, which can change how wide lines are.
    func textViewDidChangeSelection(_ notification: Notification) {
        guard isEditing, let cell = notification.object as? NoteTextView, !cell.hasMarkedText() else { return }
        let line = (cell.string as NSString).lineRange(for: cell.selectedRange())
        guard cell.revealedLines != line else { return }
        relayoutKeepingTopLeft()
    }
}
