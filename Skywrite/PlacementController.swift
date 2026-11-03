import AppKit
import SkywriteCore

final class PlacementController {
    private var panels: [PlacementPanel] = []
    private let onPlace: (NotePlacement) -> Void

    init(onPlace: @escaping (NotePlacement) -> Void) {
        self.onPlace = onPlace
    }

    var isActive: Bool {
        !panels.isEmpty
    }

    func toggle() {
        if isActive {
            cancel()
        } else {
            begin()
        }
    }

    func begin() {
        NSApp.activate()
        panels = NSScreen.screens.map { PlacementPanel(screen: $0, controller: self) }
        panels.forEach { $0.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        let target = panels.first { $0.frame.contains(mouse) } ?? panels.first
        target?.makeKey()
        target?.showHint(at: mouse)
        NSCursor.crosshair.push()
    }

    func cancel() {
        guard isActive else { return }
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        NSCursor.pop()
    }

    func finish(from start: CGPoint, to end: CGPoint) {
        cancel()
        let lineHeight = NoteController.lineHeight(zoom: 1)
        if NoteGeometry.isDrag(from: start, to: end) {
            onPlace(NoteGeometry.draggedBox(from: start, to: end, lineHeight: lineHeight))
        } else {
            onPlace(NotePlacement(topLeft: NoteGeometry.placedBox(clickPoint: start, lineHeight: lineHeight)))
        }
    }

    func mouseMoved(to location: CGPoint) {
        panels.forEach { $0.showHint(at: location) }
    }
}

final class PlacementPanel: NSPanel {
    private let placementView: PlacementView

    init(screen: NSScreen, controller: PlacementController) {
        placementView = PlacementView(controller: controller)
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setAccessibilityIdentifier("placement")
        contentView = placementView
        setFrame(screen.frame, display: false)
        makeFirstResponder(placementView)
    }

    override var canBecomeKey: Bool {
        true
    }

    func showHint(at screenLocation: CGPoint) {
        placementView.showHint(at: screenLocation)
    }
}

final class PlacementView: NSView {
    private weak var controller: PlacementController?
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private let hint = NSTextField(labelWithString: String(localized: "Click to place a note · Drag to set its size · esc to cancel"))

    init(controller: PlacementController) {
        self.controller = controller
        super.init(frame: .zero)
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .white
        hint.drawsBackground = true
        hint.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        hint.wantsLayer = true
        hint.layer?.cornerRadius = 6
        hint.layer?.masksToBounds = true
        hint.isHidden = true
        addSubview(hint)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    func showHint(at screenLocation: CGPoint) {
        guard let window, window.frame.contains(screenLocation) else {
            hint.isHidden = true
            return
        }
        let local = convert(window.convertPoint(fromScreen: screenLocation), from: nil)
        hint.sizeToFit()
        hint.setFrameOrigin(NSPoint(x: local.x + 16, y: local.y - 18 - hint.frame.height))
        hint.isHidden = false
    }

    override func mouseMoved(with event: NSEvent) {
        controller?.mouseMoved(to: NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        dragCurrent = dragStart
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = NSEvent.mouseLocation
        controller?.mouseMoved(to: NSEvent.mouseLocation)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        dragStart = nil
        dragCurrent = nil
        controller?.finish(from: start, to: NSEvent.mouseLocation)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x35 {
            controller?.cancel()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        controller?.cancel()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let start = dragStart, let current = dragCurrent, let window, NoteGeometry.isDrag(from: start, to: current) else { return }
        let startPoint = convert(window.convertPoint(fromScreen: start), from: nil)
        let endPoint = convert(window.convertPoint(fromScreen: current), from: nil)
        let rect = NSRect(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y), width: abs(startPoint.x - endPoint.x), height: abs(startPoint.y - endPoint.y))
        let path = NSBezierPath(rect: rect)
        path.lineWidth = NoteMetrics.edgeLineWidth
        path.setLineDash(NoteMetrics.edgeDashPattern, count: NoteMetrics.edgeDashPattern.count, phase: 0)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }
}
