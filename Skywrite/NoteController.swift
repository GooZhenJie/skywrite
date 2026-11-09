import AppKit
import SkywriteCore

final class NoteController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    var record: NoteRecord
    let panel = NotePanel()
    let noteView = NoteView(frame: .zero)
    let textView: NoteTextView
    private let softEdgeView = NoteSoftEdgeView()
    private let liquidGlassView = NoteLiquidGlassView()
    private(set) var style: NoteStyle
    private weak var manager: NoteManager?
    private(set) var isEditing = false
    private var textContentHeight: CGFloat = 0
    private var unlockClick: (timestamp: TimeInterval, location: CGPoint)?

    init(record: NoteRecord, text: String, style: NoteStyle, manager: NoteManager) {
        self.record = record
        self.style = style
        self.manager = manager
        textView = NoteTextLayout.makeTextView(text: text) { NoteTextView(frame: .zero, textContainer: $0) }
        super.init()
        configure()
    }

    var id: UUID {
        record.id
    }

    var text: String {
        textView.string
    }

    var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    func beginEditing(caretAt point: NSPoint?) {
        isEditing = true
        textView.isEditable = true
        textView.isSelectable = true
        panel.ignoresMouseEvents = false
        noteView.showsHandles = true
        EventLog.notes.notice("begin editing \(self.panel.identifier?.rawValue ?? "", privacy: .public) activating app, keyWindow before=\(EventLog.describe(NSApp.keyWindow), privacy: .public)")
        NSApp.activateLeavingWindowsBehind()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        if let point {
            let index = textView.characterIndexForInsertion(at: point)
            textView.setSelectedRange(NSRange(location: index, length: 0))
        } else {
            moveCaretToEnd()
        }
        manager?.bringToFront(self)
    }

    func unlock(with event: NSEvent) {
        beginEditing(caretAt: textView.convert(event.locationInWindow, from: nil))
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
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        textView.isEditable = false
        textView.isSelectable = false
        noteView.showsHandles = false
        panel.makeFirstResponder(nil)
        if !isBlank {
            keepWidthAfterLocking()
        }
        manager?.didLock(self)
        updateClickThrough(mouseLocation: NSEvent.mouseLocation)
    }

    func moveCaretToEnd() {
        panel.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
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

    func zoom(by factor: Double, around anchor: CGPoint) {
        let newZoom = NoteGeometry.clampedZoom(record.zoom * factor)
        let change = CGFloat(newZoom / record.zoom)
        guard change != 1 else { return }
        let newTopLeft = NoteGeometry.zoomedPoint(topLeft, around: anchor, factor: change)
        record.zoom = newZoom
        record.topLeftX = newTopLeft.x
        record.topLeftY = newTopLeft.y
        relayoutKeepingTopLeft()
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

    private func configure() {
        textView.controller = self
        textView.setAccessibilityIdentifier("note-text")
        textView.delegate = self
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = false
        textView.isSelectable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textContainerInset = style.textPadding(zoom: zoom)
        textView.insertionPointColor = .white
        textView.wantsLayer = true
        textView.layer?.shadowColor = NSColor.black.cgColor
        textView.layer?.shadowOpacity = 0.35
        textView.layer?.shadowRadius = 5
        textView.layer?.shadowOffset = .zero
        noteView.controller = self
        softEdgeView.material = .hudWindow
        softEdgeView.blendingMode = .behindWindow
        softEdgeView.state = .active
        noteView.addSubview(softEdgeView)
        liquidGlassView.style = .regular
        // Note text is always white, so the glass stays dark the way it would in Dark Mode.
        liquidGlassView.appearance = NSAppearance(named: .darkAqua)
        noteView.addSubview(liquidGlassView)
        noteView.addSubview(textView)
        panel.identifier = NSUserInterfaceItemIdentifier("note-\(record.id.uuidString.prefix(8))")
        panel.contentView = noteView
        panel.delegate = self
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        return [.font: style.font(zoom: zoom), .foregroundColor: NSColor.white, .shadow: shadow]
    }

    private func applyTextAttributes() {
        let attributes = textAttributes
        textView.typingAttributes = attributes
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
    }

    private var screenFrame: CGRect {
        let screen = NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? .zero
    }

    private func measuredBoxSize() -> CGSize {
        applyTextAttributes()
        let padding = style.textPadding(zoom: zoom)
        textView.textContainerInset = padding
        let horizontalPadding = padding.width * 2
        let verticalPadding = padding.height * 2
        let widthLimit = record.fixedWidth.map { CGFloat($0) * zoom }
            ?? NoteGeometry.autoWidthLimit(boxMinX: topLeft.x, screenMaxX: screenFrame.maxX)
        let textSize = NoteTextLayout.textSize(of: textView, widthLimit: widthLimit - horizontalPadding, font: style.font(zoom: zoom))
        let width = record.fixedWidth == nil ? max(NoteMetrics.minimumTextWidth, textSize.width + horizontalPadding) : widthLimit
        textContentHeight = textSize.height + verticalPadding
        let minimumHeight = record.minimumHeight.map { CGFloat($0) * zoom } ?? 0
        return CGSize(width: width, height: max(textContentHeight, minimumHeight))
    }

    private func relayoutKeepingTopLeft() {
        let size = measuredBoxSize()
        place(CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height))
    }

    private func place(_ box: CGRect) {
        let margin = NoteMetrics.windowMargin
        panel.setFrame(box.insetBy(dx: -margin, dy: -margin), display: true)
        noteView.frame = NSRect(origin: .zero, size: panel.frame.size)
        textView.frame = NSRect(x: margin, y: margin, width: box.width, height: box.height)
        layoutGlass()
        record.topLeftX = box.minX
        record.topLeftY = box.maxY
        noteView.needsDisplay = true
    }
}

extension NoteController {
    func apply(_ newStyle: NoteStyle) {
        style = newStyle
        relayoutKeepingTopLeft()
        updateClickThrough(mouseLocation: NSEvent.mouseLocation)
    }

    func layoutGlass() {
        let staysClear = style.glassStyle == .liquidGlass && style.liquidGlassStaysClear
        if panel.keepsActiveAppearance != staysClear {
            panel.keepsActiveAppearance = staysClear
            // The glass picks up the window's look when it joins the window, so put it back in to apply the change now.
            liquidGlassView.removeFromSuperview()
            noteView.addSubview(liquidGlassView, positioned: .below, relativeTo: textView)
        }
        let showsSoftEdge = style.glassStyle == .softEdge && style.showsBackground
        softEdgeView.isHidden = !showsSoftEdge
        liquidGlassView.isHidden = style.glassStyle != .liquidGlass
        switch style.glassStyle {
        case .softEdge:
            guard showsSoftEdge else { return }
            softEdgeView.alphaValue = style.glassStrength
            softEdgeView.frame = textView.frame.insetBy(dx: -NoteMetrics.frameGap, dy: -NoteMetrics.frameGap)
            softEdgeView.maskImage = Self.featheredMask(size: softEdgeView.frame.size, feather: NoteMetrics.softEdgeFeather)
        case .liquidGlass:
            liquidGlassView.frame = textView.frame
            liquidGlassView.cornerRadius = NoteMetrics.liquidGlassCornerRadius * zoom
        }
    }

    static func featheredMask(size: CGSize, feather: CGFloat) -> NSImage? {
        let width = max(1, Int(size.width.rounded(.up)))
        let height = max(1, Int(size.height.rounded(.up)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let inner = CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: feather, dy: feather)
        guard inner.width > 0, inner.height > 0 else { return nil }
        let offset = CGFloat(height) * 2
        context.setShadow(offset: CGSize(width: 0, height: -offset), blur: feather, color: CGColor(gray: 0, alpha: 1))
        context.addPath(CGPath(roundedRect: inner.offsetBy(dx: 0, dy: offset), cornerWidth: min(feather, inner.width / 2), cornerHeight: min(feather, inner.height / 2), transform: nil))
        context.fillPath()
        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: size)
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
