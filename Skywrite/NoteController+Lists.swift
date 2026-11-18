import AppKit
import SkywriteCore

/// Bulleted, numbered and task lists, drawn and typed the way Notion does it.
///
/// The marker (`- `, `1. `, `- [ ] `) turns into a bullet, number or box as soon as it's typed and is never shown as
/// text, even on the line being typed; the caret skips over it. Wrapped lines line up with the item's text. Return
/// starts the next item, Return on an empty item ends the list, Delete at the start of an item turns it back into plain
/// text, and Shift-Return starts a new line inside the same item. Tab doesn't nest items. Ticking a box is in
/// `NoteController+Tasks`.
extension NoteController {
    /// Hides each item's marker, indents the item, fades a ticked task's text, and hands the cell its bullets, numbers
    /// and boxes to draw.
    ///
    /// The marker stays in the text and is laid out, but drawn clear and kerned to no width. Giving it no glyphs the way
    /// a heading's `#` is hidden doesn't work here: a line made only of hidden glyphs, such as the empty item Return just
    /// started, gets no line of its own, so the caret and the bullet would sit at the end of the line above.
    func styleLists(in cell: NoteTextView, storage: NSTextStorage) {
        let bodyFont = style.font(zoom: zoom)
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = bodyFont.pointSize * NoteMetrics.listTextIndentScale
        paragraph.headIndent = paragraph.firstLineHeadIndent
        let checkedAttributes = checkedTaskAttributes(fading: textAttributes(font: bodyFont))
        let items = NoteMarkdown.listItems(in: cell.string)
        let string = cell.string as NSString
        var widths: [String: CGFloat] = [:]
        for item in items {
            for line in [item.lineRange] + item.continuationLines {
                storage.addAttribute(.paragraphStyle, value: paragraph, range: line)
            }
            if item.isChecked {
                item.visibleTextRanges.forEach { storage.addAttributes(checkedAttributes, range: $0) }
            }
            for hidden in item.hiddenRanges {
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: hidden)
                storage.removeAttribute(.shadow, range: hidden)
                for index in hidden.location..<NSMaxRange(hidden) {
                    let character = string.substring(with: NSRange(location: index, length: 1))
                    let width = widths[character] ?? NSAttributedString(string: character, attributes: [.font: bodyFont]).size().width
                    widths[character] = width
                    storage.addAttribute(.kern, value: -width, range: NSRange(location: index, length: 1))
                }
            }
        }
        cell.listMarkers = listMarkers(for: items)
    }

    /// While an input method is composing (Chinese pinyin, Japanese kana), AppKit changes the text without telling the
    /// delegate, so the note isn't restyled until a word is chosen. The bullets, numbers and boxes still move with their
    /// items here; otherwise the next item's number is drawn on the line being typed, such as a "1." inside a box while
    /// typing Chinese.
    func moveListMarkers(in cell: NoteTextView) {
        cell.listMarkers = listMarkers(for: NoteMarkdown.listItems(in: cell.string))
    }

    private func listMarkers(for items: [NoteListItem]) -> [NoteListMarker] {
        let bodyFont = style.font(zoom: zoom)
        let bulletAttributes = textAttributes(font: style.font(zoom: zoom * NoteMetrics.listBulletScale))
        let numberAttributes = textAttributes(font: bodyFont)
        return items.map { item in
            NoteListMarker(
                characterIndex: item.lineRange.location,
                kind: item.kind,
                label: NSAttributedString(string: item.label, attributes: item.kind == .bullet ? bulletAttributes : numberAttributes),
                columnWidth: bodyFont.pointSize * NoteMetrics.listMarkerColumnScale,
                bodyFont: bodyFont,
                shadow: numberAttributes[.shadow] as? NSShadow
            )
        }
    }

    /// A ticked task's text, the way Notion shows a done to-do: faded, with a line through it at half the text's
    /// opacity (see `NoteMetrics.checkedTaskTextOpacity`). The text's shadow fades with it.
    private func checkedTaskAttributes(fading body: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let opacity = NoteMetrics.checkedTaskTextOpacity
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(opacity),
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: NSColor.white.withAlphaComponent(opacity * NoteMetrics.checkedTaskLineOpacity)
        ]
        if let shadow = (body[.shadow] as? NSShadow)?.copy() as? NSShadow, let color = shadow.shadowColor {
            shadow.shadowColor = color.withAlphaComponent(color.alphaComponent * opacity)
            attributes[.shadow] = shadow
        }
        return attributes
    }

    /// The caret never stops inside a hidden marker or indent: it goes to the start of the item's text, or, when it was
    /// moving back from there, to the end of the line above.
    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldRange: NSRange, toCharacterRange newRange: NSRange) -> NSRange {
        guard newRange.length == 0 else { return newRange }
        let hidden = NoteMarkdown.listItems(in: textView.string).flatMap(\.hiddenRanges)
        guard let range = hidden.first(where: { NSLocationInRange(newRange.location, $0) }) else { return newRange }
        let movingBack = oldRange.length == 0 && oldRange.location == NSMaxRange(range) && newRange.location < oldRange.location
        if movingBack, range.location > 0 {
            return NSRange(location: range.location - 1, length: 0)
        }
        return NSRange(location: NSMaxRange(range), length: 0)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let cell = textView as? NoteTextView, !cell.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            return continueList(in: cell, staysInItem: NSApp.currentEvent?.modifierFlags.contains(.shift) == true)
        case #selector(NSResponder.deleteBackward(_:)):
            return removeListMarker(in: cell)
        case #selector(NSResponder.deleteForward(_:)):
            return joinNextLine(in: cell)
        default:
            return false
        }
    }

    /// Return in a list item: the next item, or the end of the list when the item is empty. With Shift, a new line
    /// inside the same item. Returns false outside a list, so Return does what it always does.
    func continueList(in cell: NoteTextView, staysInItem: Bool) -> Bool {
        let selection = cell.selectedRange()
        let items = NoteMarkdown.listItems(in: cell.string)
        guard let item = items.first(where: { selection.location >= $0.contentStart && NSMaxRange(selection) <= NSMaxRange($0.textRange) }) else { return false }
        if staysInItem {
            return replace(selection, with: "\n" + String(repeating: " ", count: item.markerRange.length), in: cell)
        }
        if item.isEmpty, selection.length == 0 {
            return replace(item.markerRange, with: "", in: cell)
        }
        return replace(selection, with: "\n" + item.nextMarker, in: cell)
    }

    /// Delete at the start of an item's text takes the bullet or number away; at the start of a line continuing an item,
    /// it joins that line to the one above. Returns false anywhere else.
    func removeListMarker(in cell: NoteTextView) -> Bool {
        let selection = cell.selectedRange()
        guard selection.length == 0 else { return false }
        for item in NoteMarkdown.listItems(in: cell.string) {
            if selection.location == item.contentStart {
                return replace(item.markerRange, with: "", in: cell)
            }
            if let indent = item.continuationIndents.first(where: { NSMaxRange($0) == selection.location }) {
                return replace(NSRange(location: indent.location - 1, length: indent.length + 1), with: "", in: cell)
            }
        }
        return false
    }

    /// Forward Delete at the end of a line whose next line is a list item (or continues one) joins that line's text on,
    /// without its hidden marker or indent. Returns false anywhere else.
    func joinNextLine(in cell: NoteTextView) -> Bool {
        let selection = cell.selectedRange()
        guard selection.length == 0 else { return false }
        let hidden = NoteMarkdown.listItems(in: cell.string).flatMap(\.hiddenRanges)
        guard let next = hidden.first(where: { $0.location == selection.location + 1 }) else { return false }
        let caret = selection.location
        _ = replace(NSRange(location: caret, length: next.length + 1), with: "", in: cell)
        cell.setSelectedRange(NSRange(location: caret, length: 0))
        return true
    }

    /// Changes the text the way typing does, so Undo takes it back, and puts the caret after the new text.
    func replace(_ range: NSRange, with text: String, in cell: NoteTextView) -> Bool {
        guard cell.shouldChangeText(in: range, replacementString: text) else { return true }
        cell.textStorage?.replaceCharacters(in: range, with: text)
        cell.didChangeText()
        cell.setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        return true
    }
}
