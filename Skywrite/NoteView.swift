import AppKit
import SkywriteCore

final class NoteView: NSView {
    weak var controller: NoteController?
    private var hoveredHandle: ResizeHandle?
    private var activeHandle: ResizeHandle?
    private var trackingArea: NSTrackingArea?

    var showsHandles = false {
        didSet {
            hoveredHandle = nil
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private var frameRect: NSRect {
        bounds.insetBy(dx: NoteMetrics.windowMargin - NoteMetrics.frameGap, dy: NoteMetrics.windowMargin - NoteMetrics.frameGap)
    }

    private func handleRect(_ handle: ResizeHandle) -> NSRect {
        let frame = frameRect
        let half = NoteMetrics.handleHitThickness / 2
        let arm = NoteMetrics.cornerArmLength
        let inset = arm + NoteMetrics.cornerToEdgeGap
        let cornerSize = half + arm
        switch handle {
        case .topLeft:
            return NSRect(x: frame.minX - half, y: frame.minY - half, width: cornerSize, height: cornerSize)
        case .topRight:
            return NSRect(x: frame.maxX - arm, y: frame.minY - half, width: cornerSize, height: cornerSize)
        case .bottomLeft:
            return NSRect(x: frame.minX - half, y: frame.maxY - arm, width: cornerSize, height: cornerSize)
        case .bottomRight:
            return NSRect(x: frame.maxX - arm, y: frame.maxY - arm, width: cornerSize, height: cornerSize)
        case .top:
            return NSRect(x: frame.minX + inset, y: frame.minY - half, width: max(0, frame.width - inset * 2), height: half * 2)
        case .bottom:
            return NSRect(x: frame.minX + inset, y: frame.maxY - half, width: max(0, frame.width - inset * 2), height: half * 2)
        case .left:
            return NSRect(x: frame.minX - half, y: frame.minY + inset, width: half * 2, height: max(0, frame.height - inset * 2))
        case .right:
            return NSRect(x: frame.maxX - half, y: frame.minY + inset, width: half * 2, height: max(0, frame.height - inset * 2))
        }
    }

    private func handle(at point: NSPoint) -> ResizeHandle? {
        guard showsHandles else { return nil }
        return ResizeHandle.allCases.first { handleRect($0).contains(point) }
    }

    private func path(for handle: ResizeHandle) -> NSBezierPath {
        let frame = frameRect
        let arm = NoteMetrics.cornerArmLength
        let inset = arm + NoteMetrics.cornerToEdgeGap
        let path = NSBezierPath()
        switch handle {
        case .topLeft:
            path.move(to: NSPoint(x: frame.minX, y: frame.minY + arm))
            path.line(to: NSPoint(x: frame.minX, y: frame.minY))
            path.line(to: NSPoint(x: frame.minX + arm, y: frame.minY))
        case .topRight:
            path.move(to: NSPoint(x: frame.maxX - arm, y: frame.minY))
            path.line(to: NSPoint(x: frame.maxX, y: frame.minY))
            path.line(to: NSPoint(x: frame.maxX, y: frame.minY + arm))
        case .bottomLeft:
            path.move(to: NSPoint(x: frame.minX, y: frame.maxY - arm))
            path.line(to: NSPoint(x: frame.minX, y: frame.maxY))
            path.line(to: NSPoint(x: frame.minX + arm, y: frame.maxY))
        case .bottomRight:
            path.move(to: NSPoint(x: frame.maxX - arm, y: frame.maxY))
            path.line(to: NSPoint(x: frame.maxX, y: frame.maxY))
            path.line(to: NSPoint(x: frame.maxX, y: frame.maxY - arm))
        case .top:
            path.move(to: NSPoint(x: frame.minX + inset, y: frame.minY))
            path.line(to: NSPoint(x: frame.maxX - inset, y: frame.minY))
        case .bottom:
            path.move(to: NSPoint(x: frame.minX + inset, y: frame.maxY))
            path.line(to: NSPoint(x: frame.maxX - inset, y: frame.maxY))
        case .left:
            path.move(to: NSPoint(x: frame.minX, y: frame.minY + inset))
            path.line(to: NSPoint(x: frame.minX, y: frame.maxY - inset))
        case .right:
            path.move(to: NSPoint(x: frame.maxX, y: frame.minY + inset))
            path.line(to: NSPoint(x: frame.maxX, y: frame.maxY - inset))
        }
        if handle.isCorner {
            path.lineWidth = NoteMetrics.cornerLineWidth
        } else {
            path.lineWidth = NoteMetrics.edgeLineWidth
            path.setLineDash(NoteMetrics.edgeDashPattern, count: NoteMetrics.edgeDashPattern.count, phase: 0)
        }
        return path
    }

    override func draw(_ dirtyRect: NSRect) {
        guard showsHandles, let context = NSGraphicsContext.current?.cgContext else { return }
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = .zero
        for handle in ResizeHandle.allCases {
            let highlighted = handle == hoveredHandle || handle == activeHandle
            context.saveGState()
            context.setAlpha(highlighted ? NoteMetrics.handleHighlightedOpacity : NoteMetrics.handleRestingOpacity)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            shadow.set()
            NSColor.white.setStroke()
            path(for: handle).stroke()
            context.endTransparencyLayer()
            context.restoreGState()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        setHoveredHandle(handle(at: point))
        updateCursor(at: point)
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        setHoveredHandle(nil)
    }

    private func updateCursor(at point: NSPoint) {
        if let handle = handle(at: point) {
            cursor(for: handle).set()
        } else if controller?.isEditing == true, let textView = controller?.textView, textView.frame.contains(point) {
            NSCursor.iBeam.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func setHoveredHandle(_ handle: ResizeHandle?) {
        guard handle != hoveredHandle else { return }
        hoveredHandle = handle
        needsDisplay = true
    }

    private func cursor(for handle: ResizeHandle) -> NSCursor {
        let position: NSCursor.FrameResizePosition = switch handle {
        case .top: .top
        case .bottom: .bottom
        case .left: .left
        case .right: .right
        case .topLeft: .topLeft
        case .topRight: .topRight
        case .bottomLeft: .bottomLeft
        case .bottomRight: .bottomRight
        }
        return NSCursor.frameResize(position: position, directions: .all)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if handle(at: local) != nil {
            return self
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        guard let controller else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let handle = handle(at: point) {
            trackResize(handle)
        } else if controller.isEditing {
            if controller.isSecondClickAfterUnlock(event) {
                controller.close()
            } else if controller.textView.frame.contains(point) {
                controller.textView.mouseDown(with: event)
            } else {
                controller.moveCaretToEnd()
            }
        } else {
            trackLockedPress(event)
        }
    }

    private func trackLockedPress(_ event: NSEvent) {
        guard let window, let controller else { return }
        let startMouse = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var moved = false
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type != .leftMouseUp {
            let current = NSEvent.mouseLocation
            let delta = CGVector(dx: current.x - startMouse.x, dy: current.y - startMouse.y)
            if !moved, hypot(delta.dx, delta.dy) > NoteMetrics.dragThreshold {
                moved = true
                NSCursor.closedHand.push()
            }
            if moved {
                window.setFrameOrigin(NSPoint(x: startOrigin.x + delta.dx, y: startOrigin.y + delta.dy))
            }
        }
        if moved {
            NSCursor.pop()
            controller.forgetUnlockClick()
            controller.didMove()
        } else if controller.isSecondClickAfterUnlock(event) {
            controller.close()
        } else {
            controller.unlock(with: event)
        }
    }

    private func trackResize(_ handle: ResizeHandle) {
        guard let window, let controller else { return }
        activeHandle = handle
        needsDisplay = true
        let startMouse = NSEvent.mouseLocation
        let startBox = controller.boxInScreen
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type != .leftMouseUp {
            let current = NSEvent.mouseLocation
            controller.resize(handle: handle, startBox: startBox, translation: CGVector(dx: current.x - startMouse.x, dy: current.y - startMouse.y))
        }
        activeHandle = nil
        needsDisplay = true
        controller.didFinishResizing()
    }

    override func scrollWheel(with event: NSEvent) {
        let physicalDeltaY = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        let factor = NoteGeometry.scrollZoomFactor(deltaY: physicalDeltaY, hasPreciseDeltas: event.hasPreciseScrollingDeltas)
        controller?.zoom(by: factor, around: NSEvent.mouseLocation)
    }

    override func magnify(with event: NSEvent) {
        controller?.zoom(by: 1 + event.magnification, around: NSEvent.mouseLocation)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let controller else { return nil }
        let menu = NSMenu()
        controller.noteMenuItems().forEach(menu.addItem)
        return menu
    }
}
