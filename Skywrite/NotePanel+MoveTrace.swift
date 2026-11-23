import AppKit

/// A note dropped across two screens used to jump a moment later: right after the mouse went up, AppKit moved the
/// window itself, without going through `setFrame`. The move is undone, and every way a note's window moves after a
/// drag is logged (with the calling code) so the cause can be traced.
extension NotePanel {
    func traceMovesAfterDrops() {
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowDidMove() }
        }
    }

    private func windowDidMove() {
        guard let dropped = droppedFrame, frame.origin != dropped.origin else {
            logMove(source: "AppKit reported a move", withCaller: true)
            return
        }
        logMove(source: "AppKit moved it after the drop; putting it back", to: dropped, withCaller: true)
        droppedFrame = nil
        setFrameOrigin(dropped.origin)
        droppedFrame = dropped
    }

    func logMove(source: String, to newFrame: NSRect? = nil, withCaller: Bool = false) {
        guard !isBeingDragged else { return }
        let target = newFrame.map { " to \(Self.text($0))" } ?? ""
        let caller = withCaller ? " caller: \(Self.caller())" : ""
        EventLog.windows.notice("note \(self.name, privacy: .public) \(source, privacy: .public): frame \(Self.text(self.frame), privacy: .public)\(target, privacy: .public) server \(self.serverFrame, privacy: .public) mouse \(Self.text(NSEvent.mouseLocation), privacy: .public) buttons=\(NSEvent.pressedMouseButtons) \(self.sinceDrop, privacy: .public)\(caller, privacy: .public)")
    }

    /// Called on mouse up, before the drop is saved. Puts the window back where the drag left it if AppKit has moved it
    /// already, then watches for half a second for AppKit moving it again.
    func dragDidEnd() {
        isBeingDragged = false
        lastDrop = Date()
        if let origin = dragOrigin, origin != frame.origin {
            logMove(source: "AppKit moved it during the drop; putting it back", to: NSRect(origin: origin, size: frame.size))
            setFrameOrigin(origin)
        }
        dragOrigin = nil
        droppedFrame = frame
        logMove(source: "dropped")
        let drop = lastDrop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if self?.lastDrop == drop {
                self?.droppedFrame = nil
            }
        }
        for delay in [0.05, 0.2, 0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.logMove(source: "check \(Int(delay * 1000))ms after drop")
            }
        }
    }

    var name: String {
        identifier?.rawValue ?? "note"
    }

    private var sinceDrop: String {
        lastDrop.map { "since drop=\(Int(Date().timeIntervalSince($0) * 1000))ms" } ?? "no drop yet"
    }

    /// The window's bounds as the window server has them, flipped into AppKit's coordinates to compare with `frame`.
    private var serverFrame: String {
        guard windowNumber > 0,
              let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(windowNumber)) as? [[String: Any]])?.first,
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds),
              let primary = NSScreen.screens.first
        else { return "unknown" }
        return Self.text(NSRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height))
    }

    private static func text(_ rect: NSRect) -> String {
        String(format: "(%.0f, %.0f, %.0f, %.0f)", rect.minX, rect.minY, rect.width, rect.height)
    }

    private static func text(_ point: NSPoint) -> String {
        String(format: "(%.0f, %.0f)", point.x, point.y)
    }

    /// The nearest callers, without addresses, so the log shows which code moved the window.
    private static func caller() -> String {
        Thread.callStackSymbols.dropFirst(3).prefix(14).map { line in
            let symbol = line.split(separator: " ", omittingEmptySubsequences: true).dropFirst(3).joined(separator: " ")
            return String(symbol.split(separator: " + ").first ?? Substring(symbol))
        }.joined(separator: " < ")
    }
}
