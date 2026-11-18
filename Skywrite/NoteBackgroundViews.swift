import AppKit

/// The backgrounds behind a note only draw. Clicks fall through to the note itself, which starts editing on the first click;
/// a background that took the click would only bring the window forward, so you'd have to click twice.
final class NoteSoftEdgeView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// Holds Liquid Glass and cuts it to its own rounded shape; set the layer's corner radius to the glass's. Liquid Glass casts
/// a soft shadow outside itself, and a window only as big as the glass, or a few points bigger, cuts that shadow off along
/// its square edges: a hard grey rectangle around a note, and dark corners and edges around the quick panel. With it cut
/// off, the only shadow left is the window's own.
class GlassClipView: NSView {
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
}

/// A note's glass, cut to shape (see `GlassClipView`). Clicks fall through to the note, like its other backgrounds.
final class NoteGlassClipView: GlassClipView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class NoteLiquidGlassView: NSGlassEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
