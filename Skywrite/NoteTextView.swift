import AppKit

final class NoteTextView: NSTextView {
    weak var controller: NoteController?

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
