import AppKit
import SkywriteCore

/// The lighter rounded tile behind each cell of a note with cells, locked or not, so each cell reads as its own box. A
/// tile covers its cell exactly; see `NoteCellGeometry.spacing`.
///
/// A view of its own, between the note's glass and its text: the glass is a subview of the note view, so anything the note
/// view draws itself inside the box ends up underneath the glass and can't be seen. It lets every click through to the
/// cells and the note view.
final class NoteCellTileView: NSView {
    weak var controller: NoteController?

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let controller, controller.layout.isGrid else { return }
        let margin = NoteMetrics.windowMargin
        let radius = NoteMetrics.cellTileCornerRadius * controller.zoom
        NSColor.white.withAlphaComponent(NoteMetrics.cellTileOpacity).setFill()
        for tile in controller.cellFrames {
            NSBezierPath(roundedRect: tile.offsetBy(dx: margin, dy: margin), xRadius: radius, yRadius: radius).fill()
        }
    }
}
