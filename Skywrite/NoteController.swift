import AppKit
import SkywriteCore

final class NoteController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    var record: NoteRecord
    let panel = NotePanel()
    let noteView = NoteView(frame: .zero)
    /// How the note is split into cells, and front matter to keep when saving. A plain note has one cell.
    private var document: NoteDocument
    /// One text view per cell, in reading order.
    let cellViews: [NoteTextView]
    let softEdgeView = NoteSoftEdgeView()
    let liquidGlassView = NoteLiquidGlassView()
    let liquidGlassClipView = NoteGlassClipView()
    private let cellTileView = NoteCellTileView()
    private(set) var style: NoteStyle
    private weak var manager: NoteManager?
    private(set) var isEditing = false
    /// How tall the text is, without any extra height the note was stretched to; set by `measuredBoxSize()`.
    var textContentHeight: CGFloat = 0
    /// Where each cell sits in the box, from the last time the note measured its text; see `NoteCellGeometry`.
    var cellFrames: [CGRect] = []
    private var unlockClick: (timestamp: TimeInterval, location: CGPoint)?

    init(record: NoteRecord, document: NoteDocument, style: NoteStyle, manager: NoteManager) {
        self.record = record
        self.document = document
        self.style = style
        self.manager = manager
        cellViews = document.cells.map { cell in NoteTextLayout.makeTextView(text: cell) { NoteTextView(frame: .zero, textContainer: $0) } }
        super.init()
        configure()
    }

    var id: UUID {
        record.id
    }

    var layout: NoteLayout {
        document.layout
    }

    /// What goes in the note's file. A note with cells and nothing typed in them has no text, so it leaves no file behind,
    /// the way an empty plain note doesn't.
    var text: String {
        var current = document
        current.setCells(cellViews.map(\.string))
        if layout.isGrid, current.isBlank {
            return ""
        }
        return current.text
    }

    var isBlank: Bool {
        cellViews.allSatisfy { $0.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The cell being typed in, or the first cell.
    var activeCell: NoteTextView {
        cellViews.first { panel.firstResponder === $0 } ?? cellViews[0]
    }

    /// The cell under a point in the note view's coordinates.
    func cell(at point: NSPoint) -> NoteTextView? {
        cellViews.first { $0.frame.contains(point) }
    }

    /// Covers every cell: the area the background is drawn behind.
    var contentFrame: NSRect {
        let margin = NoteMetrics.windowMargin
        return NSRect(x: margin, y: margin, width: boxInScreen.width, height: boxInScreen.height)
    }

    var zoom: CGFloat {
        CGFloat(record.zoom)
    }

    var topLeft: CGPoint {
        CGPoint(x: record.topLeftX, y: record.topLeftY)
    }

    var boxInScreen: CGRect {
        panel.frame.insetBy(dx: NoteMetrics.windowMargin, dy: NoteMetrics.windowMargin)
    }

    func move(toTopLeft point: CGPoint) {
        record.topLeftX = point.x
        record.topLeftY = point.y
        relayoutKeepingTopLeft()
        manager?.layoutDidChange(self)
    }

    func show(editing: Bool) {
        relayoutKeepingTopLeft()
        panel.orderFrontRegardless()
        if editing {
            beginEditing(caretAt: nil)
        } else {
            // Notes saved before widths were kept on locking come back with no fixed width; they've all been locked already.
            keepWidthAfterLocking()
            updateClickThrough(mouseLocation: NSEvent.mouseLocation)
        }
    }

    func dismiss() {
        isEditing = false
        panel.delegate = nil
        panel.orderOut(nil)
    }

    /// Starts typing in `cell` (the first cell when nil), with the caret at `point` in that cell's coordinates or at its end.
    func beginEditing(in cell: NoteTextView? = nil, caretAt point: NSPoint?) {
        let cell = cell ?? cellViews[0]
        isEditing = true
        cellViews.forEach {
            $0.isEditable = true
            $0.isSelectable = true
        }
        panel.ignoresMouseEvents = false
        noteView.showsHandles = true
        EventLog.notes.notice("begin editing \(self.panel.identifier?.rawValue ?? "", privacy: .public) activating app, keyWindow before=\(EventLog.describe(NSApp.keyWindow), privacy: .public)")
        NSApp.activateLeavingWindowsBehind()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(cell)
        if let point {
            let index = cell.characterIndexForInsertion(at: point)
            cell.setSelectedRange(NSRange(location: index, length: 0))
        } else {
            moveCaretToEnd(of: cell)
        }
        // Shows the heading marks on the caret's line.
        relayoutKeepingTopLeft()
        manager?.bringToFront(self)
    }

    func unlock(with event: NSEvent) {
        let cell = cell(at: noteView.convert(event.locationInWindow, from: nil)) ?? cellViews[0]
        beginEditing(in: cell, caretAt: cell.convert(event.locationInWindow, from: nil))
        unlockClick = (event.timestamp, screenLocation(of: event))
    }

    func isSecondClickAfterUnlock(_ event: NSEvent) -> Bool {
        guard let unlockClick else { return false }
        let location = screenLocation(of: event)
        let elapsed = event.timestamp - unlockClick.timestamp
        let distance = hypot(location.x - unlockClick.location.x, location.y - unlockClick.location.y)
        let quickEnough = elapsed <= NSEvent.doubleClickInterval
        let closeEnough = distance <= NoteMetrics.dragThreshold
        let isSecondClick = quickEnough && closeEnough
        // Only near misses: a click that was quick but moved, or stayed put but came late. A later, unrelated click isn't logged.
        if !isSecondClick, quickEnough || closeEnough {
            EventLog.notes.notice("click after unlock not counted as a double-click \(self.panel.identifier?.rawValue ?? "", privacy: .public) elapsed=\(elapsed, format: .fixed(precision: 3), privacy: .public)s limit=\(NSEvent.doubleClickInterval, format: .fixed(precision: 3), privacy: .public)s distance=\(distance, format: .fixed(precision: 1), privacy: .public)pt limit=\(NoteMetrics.dragThreshold, format: .fixed(precision: 1), privacy: .public)pt")
        }
        return isSecondClick
    }

    func forgetUnlockClick() {
        unlockClick = nil
    }

    private func screenLocation(of event: NSEvent) -> CGPoint {
        panel.convertPoint(toScreen: event.locationInWindow)
    }

    func lock() {
        guard isEditing else { return }
        EventLog.notes.notice("lock \(self.panel.identifier?.rawValue ?? "", privacy: .public)")
        isEditing = false
        cellViews.forEach {
            $0.setSelectedRange(NSRange(location: ($0.string as NSString).length, length: 0))
            $0.isEditable = false
            $0.isSelectable = false
        }
        noteView.showsHandles = false
        panel.makeFirstResponder(nil)
        // Hides every heading mark before the width is kept.
        relayoutKeepingTopLeft()
        if !isBlank {
            keepWidthAfterLocking()
        }
        manager?.didLock(self)
        updateClickThrough(mouseLocation: NSEvent.mouseLocation)
    }

    /// Puts the caret at the end of `cell`, or of the cell being typed in.
    func moveCaretToEnd(of cell: NoteTextView? = nil) {
        let cell = cell ?? activeCell
        panel.makeFirstResponder(cell)
        cell.setSelectedRange(NSRange(location: (cell.string as NSString).length, length: 0))
    }

    func close() {
        manager?.close(self)
    }

    func didMove() {
        let box = boxInScreen
        record.topLeftX = box.minX
        record.topLeftY = box.maxY
        relayoutKeepingTopLeft()
        manager?.layoutDidChange(self)
    }

    func resize(handle: ResizeHandle, startBox: CGRect, translation: CGVector) {
        let minimum = CGSize(width: NoteMetrics.minimumFixedWidth, height: style.lineHeight(zoom: zoom) + style.textPadding(zoom: zoom).height * 2)
        let requested = NoteGeometry.requestedSize(start: startBox, handle: handle, translation: translation, minimumSize: minimum)
        if handle.changesWidth {
            record.fixedWidth = Double(requested.width / zoom)
        }
        if handle.changesHeight {
            record.minimumHeight = Double(requested.height / zoom)
        }
        record.topLeftX = handle.movesLeft ? startBox.maxX - requested.width : startBox.minX
        place(NoteGeometry.anchoredBox(start: startBox, handle: handle, size: measuredBoxSize()))
    }

    func didFinishResizing() {
        manager?.layoutDidChange(self)
    }

    /// Zooms around `anchor`, the mouse. Zooming in stops when the note is as big as the screen the mouse is on, and moves
    /// the note in from any edge of that screen it would cross, so all of it stays in sight; zooming out leaves it where
    /// it shrinks to. See `NoteGeometry.zoomFitting`.
    func zoom(by factor: Double, around anchor: CGPoint) {
        let screen = (NSScreen.screens.first { $0.frame.contains(anchor) } ?? panel.screen)?.visibleFrame
        let box = boxInScreen
        var newZoom = NoteGeometry.clampedZoom(record.zoom * factor)
        if let screen {
            newZoom = NoteGeometry.zoomFitting(newZoom, currentZoom: record.zoom, box: box.size, in: screen.size)
        }
        let change = CGFloat(newZoom / record.zoom)
        guard change != 1 else { return }
        let newTopLeft = NoteGeometry.zoomedPoint(topLeft, around: anchor, factor: change)
        record.zoom = newZoom
        record.topLeftX = newTopLeft.x
        record.topLeftY = newTopLeft.y
        relayoutKeepingTopLeft()
        if let screen, change > 1 {
            let inside = NoteGeometry.moved(boxInScreen, inside: screen)
            if inside.origin != boxInScreen.origin {
                record.topLeftX = inside.minX
                record.topLeftY = inside.maxY
                relayoutKeepingTopLeft()
            }
        }
        manager?.layoutDidChange(self)
    }

    func updateClickThrough(mouseLocation: CGPoint) {
        guard !isEditing else {
            panel.ignoresMouseEvents = false
            return
        }
        let box = boxInScreen
        let textArea = style.showsBackground ? box : CGRect(x: box.minX, y: box.maxY - textContentHeight, width: box.width, height: textContentHeight)
        panel.ignoresMouseEvents = !textArea.contains(mouseLocation)
    }

    func windowDidResignKey(_ notification: Notification) {
        lock()
    }

    func textDidChange(_ notification: Notification) {
        relayoutKeepingTopLeft()
        manager?.textDidChange(self)
    }

    func relayoutKeepingTopLeft() {
        let size = measuredBoxSize()
        place(CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height))
    }

    private func place(_ box: CGRect) {
        let margin = NoteMetrics.windowMargin
        panel.setFrame(box.insetBy(dx: -margin, dy: -margin), display: true)
        noteView.frame = NSRect(origin: .zero, size: panel.frame.size)
        for (cell, frame) in zip(cellViews, cellFrames) {
            cell.frame = frame.offsetBy(dx: margin, dy: margin)
        }
        layoutGlass()
        cellTileView.frame = noteView.bounds
        cellTileView.needsDisplay = true
        record.topLeftX = box.minX
        record.topLeftY = box.maxY
        noteView.needsDisplay = true
    }
}

extension NoteController {
    private func configure() {
        for (index, cell) in cellViews.enumerated() {
            cell.controller = self
            cell.setAccessibilityIdentifier(index == 0 ? "note-text" : "note-text-\(index + 1)")
            cell.delegate = self
            cell.layoutManager?.delegate = self
            cell.drawsBackground = false
            cell.isRichText = false
            cell.importsGraphics = false
            cell.allowsUndo = true
            cell.isEditable = false
            cell.isSelectable = false
            cell.isHorizontallyResizable = false
            cell.isVerticallyResizable = false
            cell.textContainerInset = style.textPadding(zoom: zoom)
            cell.insertionPointColor = .white
            // Selected text keeps its own colour. AppKit's default selection recolours the text, which would also show
            // the list markers drawn clear in `styleLists`, such as a "1." over each item's text.
            cell.selectedTextAttributes = cell.selectedTextAttributes.filter { $0.key != .foregroundColor }
            cell.wantsLayer = true
            cell.layer?.shadowColor = NSColor.black.cgColor
            cell.layer?.shadowOpacity = 0.35
            cell.layer?.shadowRadius = 5
            cell.layer?.shadowOffset = .zero
        }
        noteView.controller = self
        softEdgeView.material = .hudWindow
        softEdgeView.blendingMode = .behindWindow
        softEdgeView.state = .active
        noteView.addSubview(softEdgeView)
        liquidGlassView.style = .regular
        // Note text is always white, so the glass stays dark the way it would in Dark Mode.
        liquidGlassView.appearance = NSAppearance(named: .darkAqua)
        liquidGlassClipView.addSubview(liquidGlassView)
        noteView.addSubview(liquidGlassClipView)
        // Above the glass and below the text; see `NoteCellTileView`.
        cellTileView.controller = self
        cellTileView.isHidden = !layout.isGrid
        noteView.addSubview(cellTileView)
        cellViews.forEach(noteView.addSubview)
        panel.identifier = NSUserInterfaceItemIdentifier("note-\(record.id.uuidString.prefix(8))")
        panel.contentView = noteView
        panel.delegate = self
    }

    func apply(_ newStyle: NoteStyle) {
        style = newStyle
        relayoutKeepingTopLeft()
        updateClickThrough(mouseLocation: NSEvent.mouseLocation)
    }

    /// Once a note has been locked, only the user changes its width (by resizing it); see `NoteGeometry.widthAfterLocking`.
    private func keepWidthAfterLocking() {
        guard record.fixedWidth == nil else { return }
        record.fixedWidth = NoteGeometry.widthAfterLocking(fixedWidth: nil, boxWidth: boxInScreen.width, zoom: zoom)
        manager?.layoutDidChange(self)
    }

    @objc func resetZoom(_ sender: Any?) {
        record.zoom = 1
        relayoutKeepingTopLeft()
        manager?.layoutDidChange(self)
    }

    @objc func fitSizeToText(_ sender: Any?) {
        record.fixedWidth = nil
        record.minimumHeight = nil
        relayoutKeepingTopLeft()
        if !isEditing {
            keepWidthAfterLocking()
        }
        manager?.layoutDidChange(self)
    }

    @objc func closeNote(_ sender: Any?) {
        close()
    }

    @objc func togglePin(_ sender: Any?) {
        manager?.togglePin(self)
    }

    func noteMenuItems() -> [NSMenuItem] {
        var items = [
            NSMenuItem(title: record.isPinned ? String(localized: "Unpin Note") : String(localized: "Pin Note"), action: #selector(togglePin(_:)), keyEquivalent: ""),
            NSMenuItem(title: String(localized: "Reset Zoom"), action: #selector(resetZoom(_:)), keyEquivalent: "")
        ]
        if record.fixedWidth != nil || record.minimumHeight != nil {
            items.append(NSMenuItem(title: String(localized: "Fit Size to Text"), action: #selector(fitSizeToText(_:)), keyEquivalent: ""))
        }
        items.append(NSMenuItem(title: String(localized: "Close Note"), action: #selector(closeNote(_:)), keyEquivalent: ""))
        items.forEach { $0.target = self }
        return items
    }
}
