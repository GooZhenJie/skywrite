import AppKit
import SkywriteCore

final class NoteTextView: NSTextView {
    weak var controller: NoteController?
    /// The lines whose heading marks are showing because the caret or selection is on them; nil when none are.
    var revealedLines: NSRange?

    /// The bullet, number or box in front of each list item, drawn in the space the hidden marker leaves; see `styleLists`.
    var listMarkers: [NoteListMarker] = [] {
        didSet { needsDisplay = true }
    }

    /// The task whose box is under `point`, in this view's coordinates.
    func taskMarker(at point: NSPoint) -> NoteListMarker? {
        markerPlacements().first { placement in
            guard case .task = placement.marker.kind else { return false }
            return placement.marker.boxRect(columnX: placement.columnX, baseline: placement.baseline).contains(point)
        }?.marker
    }

    /// A marker, the left edge of its column, and the baseline of its item's first line.
    private struct MarkerPlacement {
        let marker: NoteListMarker
        let columnX: CGFloat
        let baseline: CGFloat
    }

    private func markerPlacements() -> [MarkerPlacement] {
        guard !listMarkers.isEmpty, let layoutManager, let textContainer else { return [] }
        let length = (string as NSString).length
        return listMarkers.filter { $0.characterIndex < length }.map { marker in
            let glyph = layoutManager.glyphIndexForCharacter(at: marker.characterIndex)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = line.minY + layoutManager.location(forGlyphAt: glyph).y
            return MarkerPlacement(marker: marker, columnX: textContainerOrigin.x + line.minX + textContainer.lineFragmentPadding, baseline: textContainerOrigin.y + baseline)
        }
    }

    /// `[]` then a space turns into a box; see `NoteController.convertTaskShortcut`.
    override func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? String) ?? (string as? NSAttributedString)?.string
        if replacementRange.location == NSNotFound, let text, controller?.convertTaskShortcut(in: self, typing: text) == true {
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    /// See `NoteController.moveListMarkers(in:)`.
    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        controller?.moveListMarkers(in: self)
    }

    /// Copying (and dragging text out) gives only the text you see: no `#` in front of headings, and no fonts or colours,
    /// since the note's white text would vanish on a white page. List markers stay as typed (`- `, `1. `, `- [x] `), so a
    /// pasted list is still a list.
    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let text = selectedRanges.map { NoteMarkdown.plainText(of: string, in: $0.rangeValue) }.joined(separator: "\n")
        pboard.declareTypes([.string], owner: nil)
        return pboard.setString(text, forType: .string)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for placement in markerPlacements() {
            placement.marker.draw(columnX: placement.columnX, baseline: placement.baseline)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard controller?.isEditing == true else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let controller else {
            super.mouseDown(with: event)
            return
        }
        if controller.isSecondClickAfterUnlock(event) {
            controller.close()
            return
        }
        controller.forgetUnlockClick()
        // A click on a box ticks it and leaves the caret where it was.
        if let marker = taskMarker(at: convert(event.locationInWindow, from: nil)) {
            controller.toggleTask(startingAt: marker.characterIndex, in: self)
            return
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
    }

    override func mouseMoved(with event: NSEvent) {
        superview?.mouseMoved(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        superview?.cursorUpdate(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        controller?.lock()
    }

    override func scrollWheel(with event: NSEvent) {
        superview?.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        superview?.magnify(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard let controller else { return menu }
        menu.addItem(.separator())
        controller.noteMenuItems().forEach(menu.addItem)
        return menu
    }
}
