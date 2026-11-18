import AppKit
import SkywriteCore

/// The bullet, number or box drawn in front of a list item; see `NoteController.styleLists`.
struct NoteListMarker {
    /// Where the item's line starts.
    let characterIndex: Int
    let kind: NoteListItem.Kind
    /// "•", or the item's number with its `.` or `)`, in the note's text style. Empty for a task, which gets a box.
    let label: NSAttributedString
    let columnWidth: CGFloat
    let bodyFont: NSFont
    /// The text's shadow. A task's box has it too, so the box shows over a light background the way the text does.
    let shadow: NSShadow?

    /// The blue Notion fills a ticked box with in Dark Mode, rgb(39, 131, 222), measured on the same page as
    /// `NoteMetrics.taskBoxScale`. The note's glass is always dark, so Dark Mode's colour is the one that fits.
    static let checkedFill = NSColor(srgbRed: 39 / 255, green: 131 / 255, blue: 222 / 255, alpha: 1)
    /// The tick's three corners, as fractions of the box from its top left, and its thickness as a fraction of the
    /// box's width: the proportions of the tick in Notion's box (a 16-unit icon drawn 14 points wide and 1 point in from
    /// the box's edge, with a stroke 1.75 units thick), measured on the same page.
    private static let tickCorners = [CGPoint(x: 0.259, y: 0.516), CGPoint(x: 0.456, y: 0.724), CGPoint(x: 0.741, y: 0.259)]
    private static let tickThickness: CGFloat = 0.0957

    /// Centred in the marker column. A number sits on the line's baseline; the larger bullet is centred on the middle
    /// of the line's lowercase letters, the way Notion's bullet lines up with the text beside it; a box is centred on
    /// the middle of the line's text.
    func draw(columnX: CGFloat, baseline: CGFloat) {
        let center = columnX + columnWidth / 2
        switch kind {
        case .bullet:
            let bounds = label.boundingRect(with: .zero, options: [.usesDeviceMetrics])
            let middle = baseline - bodyFont.xHeight / 2
            label.draw(with: NSRect(x: center - bounds.midX, y: middle + bounds.midY, width: 0, height: 0), options: [])
        case .numbered:
            label.draw(with: NSRect(x: center - label.size().width / 2, y: baseline, width: 0, height: 0), options: [])
        case .task(let isChecked):
            drawBox(in: boxRect(columnX: columnX, baseline: baseline), isChecked: isChecked)
        }
    }

    /// Where a task's box goes in a flipped view: as big as the text, centred in the column and on the middle of the
    /// line's text, from the top of its tallest letters to the bottom of its lowest, the way Notion places it.
    func boxRect(columnX: CGFloat, baseline: CGFloat) -> NSRect {
        let size = bodyFont.pointSize * NoteMetrics.taskBoxScale
        let middle = baseline - (bodyFont.ascender + bodyFont.descender) / 2
        return NSRect(x: columnX + (columnWidth - size) / 2, y: middle - size / 2, width: size, height: size)
    }

    /// An outline in the text's colour, or, once ticked, filled blue with a white tick.
    private func drawBox(in box: NSRect, isChecked: Bool) {
        let border = bodyFont.pointSize * NoteMetrics.taskBoxBorderScale
        let corner = bodyFont.pointSize * NoteMetrics.taskBoxCornerScale
        NSGraphicsContext.saveGraphicsState()
        shadow?.set()
        if isChecked {
            Self.checkedFill.setFill()
            NSBezierPath(roundedRect: box, xRadius: corner, yRadius: corner).fill()
        } else {
            let outline = NSBezierPath(roundedRect: box.insetBy(dx: border / 2, dy: border / 2), xRadius: corner, yRadius: corner)
            outline.lineWidth = border
            NSColor.white.setStroke()
            outline.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        guard isChecked else { return }
        let tick = NSBezierPath()
        for (index, fraction) in Self.tickCorners.enumerated() {
            let point = NSPoint(x: box.minX + fraction.x * box.width, y: box.minY + fraction.y * box.height)
            if index == 0 {
                tick.move(to: point)
            } else {
                tick.line(to: point)
            }
        }
        tick.lineWidth = Self.tickThickness * box.width
        tick.lineCapStyle = .round
        tick.lineJoinStyle = .round
        NSColor.white.setStroke()
        tick.stroke()
    }
}
