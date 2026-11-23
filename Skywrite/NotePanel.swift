import AppKit
import ObjectiveC

final class NotePanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        isMovable = false
        animationBehavior = .none
        // Notes follow you to every desktop and over full-screen apps, the way Snipaste pins do.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        traceMovesAfterDrops()
    }

    var moveObserver: NSObjectProtocol?
    var lastDrop: Date?
    /// Where Skywrite last put the window during a drag, and for half a second after it; see `NotePanel+MoveTrace`.
    var dragOrigin: NSPoint?
    var droppedFrame: NSRect?

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        if frameRect.origin != frame.origin {
            logMove(source: "setFrame", to: frameRect, withCaller: true)
        }
        if droppedFrame != nil {
            droppedFrame = frameRect
        }
        super.setFrame(frameRect, display: flag)
    }

    override func setFrameOrigin(_ point: NSPoint) {
        if point != frame.origin {
            logMove(source: "setFrameOrigin", to: NSRect(origin: point, size: frame.size), withCaller: true)
        }
        if isBeingDragged {
            dragOrigin = point
        }
        if droppedFrame != nil {
            droppedFrame = NSRect(origin: point, size: frame.size)
        }
        super.setFrameOrigin(point)
    }

    /// AppKit keeps a window's top edge below the menu bar. A note may go there, and past any other edge, as long as part
    /// of it stays in sight; `NoteController.didMove` sees to that. Any frame AppKit would have changed is logged, so a
    /// note that jumps on its own can be traced.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let constrained = super.constrainFrameRect(frameRect, to: screen)
        if constrained != frameRect, !isBeingDragged {
            logMove(source: "constrainFrameRect", to: frameRect, withCaller: true)
            EventLog.windows.notice("note \(self.identifier?.rawValue ?? "note", privacy: .public) AppKit would have moved it from \(String(describing: frameRect), privacy: .public) to \(String(describing: constrained), privacy: .public); kept where it was")
        }
        return frameRect
    }

    /// Set while the note follows the mouse, when every step past the menu bar would otherwise be logged.
    var isBeingDragged = false

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Liquid Glass dims itself in windows that aren't active. Turned on, the note keeps the clear look you see while editing.
    var keepsActiveAppearance = false

    /// Undocumented: AppKit asks windows this (macOS 26 and 27) to decide whether to draw their active look, and the glass
    /// follows the answer. Checked 2026-11-07: answering yes gives an unfocused note the same glass settings as a focused one.
    /// If a later macOS stops asking, nothing breaks; the glass just dims again.
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { // swiftlint:disable:this identifier_name - AppKit's own name
        keepsActiveAppearance || Self.systemHasActiveAppearance(self)
    }

    private static let activeAppearanceSelector = NSSelectorFromString("_hasActiveAppearanceIgnoringKeyFocus")

    private static func systemHasActiveAppearance(_ window: NSWindow) -> Bool {
        guard let method = class_getInstanceMethod(NSPanel.self, activeAppearanceSelector) else { return false }
        typealias Implementation = @convention(c) (AnyObject, Selector) -> Bool
        let implementation = unsafeBitCast(method_getImplementation(method), to: Implementation.self)
        return implementation(window, activeAppearanceSelector)
    }
}
