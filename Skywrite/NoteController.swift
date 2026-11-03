import AppKit
import SkywriteCore

final class NoteController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    var record: NoteRecord
    let panel = NotePanel()
    let noteView = NoteView(frame: .zero)
    let textView: NoteTextView
    private weak var manager: NoteManager?
    private(set) var isEditing = false
    private var textContentHeight: CGFloat = 0
    private var unlockClick: (timestamp: TimeInterval, location: CGPoint)?

    init(record: NoteRecord, text: String, manager: NoteManager) {
        self.record = record
        self.manager = manager
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        textView = NoteTextView(frame: .zero, textContainer: container)
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

    static func font(zoom: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: NoteMetrics.baseFontSize * zoom, weight: .medium)
    }

    static func lineHeight(zoom: CGFloat) -> CGFloat {
        NSLayoutManager().defaultLineHeight(for: font(zoom: zoom))
    }

    func show(editing: Bool) {
        relayoutKeepingTopLeft()
        panel.orderFrontRegardless()
        if editing {
            beginEditing(caretAt: nil)
        } else {
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
        NSApp.activate()
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
        return elapsed <= NSEvent.doubleClickInterval && distance <= NoteMetrics.dragThreshold
    }

    func forgetUnlockClick() {
        unlockClick = nil
    }

    private func screenLocation(of event: NSEvent) -> CGPoint {
        panel.convertPoint(toScreen: event.locationInWindow)
    }

    func lock() {
        guard isEditing else { return }
        isEditing = false
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        textView.isEditable = false
        textView.isSelectable = false
        noteView.showsHandles = false
        panel.makeFirstResponder(nil)
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
        let minimum = CGSize(width: NoteMetrics.minimumFixedWidth, height: Self.lineHeight(zoom: zoom) + NoteMetrics.textVerticalPadding * 2)
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
        let textArea = CGRect(x: box.minX, y: box.maxY - textContentHeight, width: box.width, height: textContentHeight)
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
        textView.textContainerInset = NSSize(width: NoteMetrics.textHorizontalPadding, height: NoteMetrics.textVerticalPadding)
        textView.insertionPointColor = .white
        textView.wantsLayer = true
        textView.layer?.shadowColor = NSColor.black.cgColor
        textView.layer?.shadowOpacity = 0.35
        textView.layer?.shadowRadius = 5
        textView.layer?.shadowOffset = .zero
        noteView.controller = self
        noteView.addSubview(textView)
        panel.contentView = noteView
        panel.delegate = self
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        return [.font: Self.font(zoom: zoom), .foregroundColor: NSColor.white, .shadow: shadow]
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
        guard let container = textView.textContainer, let layoutManager = textView.layoutManager else { return .zero }
        let horizontalPadding = NoteMetrics.textHorizontalPadding * 2
        let verticalPadding = NoteMetrics.textVerticalPadding * 2
        let widthLimit = record.fixedWidth.map { CGFloat($0) * zoom }
            ?? NoteGeometry.autoWidthLimit(boxMinX: topLeft.x, screenMaxX: screenFrame.maxX)
        container.size = NSSize(width: max(1, widthLimit - horizontalPadding), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        let lineHeight = layoutManager.defaultLineHeight(for: Self.font(zoom: zoom))
        let width = record.fixedWidth == nil ? max(NoteMetrics.minimumTextWidth, ceil(used.width) + horizontalPadding) : widthLimit
        textContentHeight = max(ceil(used.height), lineHeight) + verticalPadding
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
        record.topLeftX = box.minX
        record.topLeftY = box.maxY
        noteView.needsDisplay = true
    }
}

extension NoteController {
    @objc func resetZoom(_ sender: Any?) {
        record.zoom = 1
        relayoutKeepingTopLeft()
        manager?.layoutDidChange(self)
    }

    @objc func fitSizeToText(_ sender: Any?) {
        record.fixedWidth = nil
        record.minimumHeight = nil
        relayoutKeepingTopLeft()
        manager?.layoutDidChange(self)
    }

    @objc func closeNote(_ sender: Any?) {
        close()
    }

    func noteMenuItems() -> [NSMenuItem] {
        var items = [NSMenuItem(title: String(localized: "Reset Zoom"), action: #selector(resetZoom(_:)), keyEquivalent: "")]
        if record.fixedWidth != nil || record.minimumHeight != nil {
            items.append(NSMenuItem(title: String(localized: "Fit Size to Text"), action: #selector(fitSizeToText(_:)), keyEquivalent: ""))
        }
        items.append(NSMenuItem(title: String(localized: "Close Note"), action: #selector(closeNote(_:)), keyEquivalent: ""))
        items.forEach { $0.target = self }
        return items
    }
}
