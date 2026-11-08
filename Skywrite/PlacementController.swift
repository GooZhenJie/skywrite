import AppKit
import SkywriteCore

final class PlacementController {
    private var panels: [PlacementPanel] = []
    /// The app that was in front when placement began, or nil when that was Skywrite itself.
    private var previousApp: NSRunningApplication?
    private let onPlace: (NotePlacement) -> Void
    private let lineHeight: () -> CGFloat
    private let padding: () -> CGSize

    init(lineHeight: @escaping () -> CGFloat, padding: @escaping () -> CGSize, onPlace: @escaping (NotePlacement) -> Void) {
        self.lineHeight = lineHeight
        self.padding = padding
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
        EventLog.input.notice("placement begin, activating app, active=\(NSApp.isActive, privacy: .public) keyWindow before=\(EventLog.describe(NSApp.keyWindow), privacy: .public)")
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost == .current ? nil : frontmost
        NSApp.activateLeavingWindowsBehind()
        panels = NSScreen.screens.map { PlacementPanel(screen: $0, controller: self) }
        panels.forEach { $0.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        let target = panels.first { $0.frame.contains(mouse) } ?? panels.first
        target?.makeKey()
        target?.showHint(at: mouse)
        NSCursor.crosshair.push()
    }

    /// Esc, or the shortcut again: puts the placement layer away and goes back to the app you were in.
    ///
    /// The front goes back before the layer does; otherwise AppKit makes another Skywrite window key as soon as
    /// the layer is gone, and a settings window left open would come forward.
    func cancel() {
        guard isActive else { return }
        if let previousApp {
            NSApp.yieldActivation(to: previousApp)
            let accepted = previousApp.activate(from: .current, options: [])
            EventLog.input.notice("placement cancelled, back to \(previousApp.bundleIdentifier ?? "unknown", privacy: .public) accepted=\(accepted, privacy: .public)")
        }
        removePanels()
    }

    /// The new note becomes the key window while the layer is still up. Taking the layer away first left no key
    /// window for a moment, and AppKit then brought the settings window forward (measured with a probe app, 2026-11-06).
    func finish(from start: CGPoint, to end: CGPoint) {
        let lineHeight = lineHeight()
        if NoteGeometry.isDrag(from: start, to: end) {
            onPlace(NoteGeometry.draggedBox(from: start, to: end, lineHeight: lineHeight, verticalPadding: padding().height))
        } else {
            onPlace(NotePlacement(topLeft: NoteGeometry.placedBox(clickPoint: start, lineHeight: lineHeight, padding: padding())))
        }
        removePanels()
    }

    private func removePanels() {
        guard isActive else { return }
        EventLog.input.notice("placement end")
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        NSCursor.pop()
        previousApp = nil
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
    private let hintBackground = NSView()

    init(controller: PlacementController) {
        self.controller = controller
        super.init(frame: .zero)
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .white
        hintBackground.wantsLayer = true
        hintBackground.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        hintBackground.layer?.cornerRadius = NoteMetrics.placementHintCornerRadius
        hintBackground.isHidden = true
        hintBackground.addSubview(hint)
        addSubview(hintBackground)
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
            hintBackground.isHidden = true
            return
        }
        let local = convert(window.convertPoint(fromScreen: screenLocation), from: nil)
        hint.sizeToFit()
        hint.setFrameOrigin(NSPoint(x: NoteMetrics.placementHintHorizontalPadding, y: NoteMetrics.placementHintVerticalPadding))
        let size = NSSize(
            width: hint.frame.width + NoteMetrics.placementHintHorizontalPadding * 2,
            height: hint.frame.height + NoteMetrics.placementHintVerticalPadding * 2
        )
        hintBackground.frame = NSRect(x: local.x + 16, y: local.y - 18 - size.height, width: size.width, height: size.height)
        hintBackground.isHidden = false
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
