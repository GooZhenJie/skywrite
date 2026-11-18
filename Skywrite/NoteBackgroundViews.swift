import AppKit

/// The backgrounds behind a note only draw. Clicks fall through to the note itself, which starts editing on the first click;
/// a background that took the click would only bring the window forward, so you'd have to click twice.
final class NoteSoftEdgeView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// Holds the glass and cuts it to its own rounded shape. Liquid Glass casts a soft shadow outside itself, and the note's
/// window is only a few points bigger than the glass, so that shadow used to end in a hard grey rectangle at the window's
/// edge. With it cut off, the only shadow a note can have is the window's own (the Shadow setting).
final class NoteGlassClipView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class NoteLiquidGlassView: NSGlassEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
