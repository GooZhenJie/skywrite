import AppKit

/// The backgrounds behind a note only draw. Clicks fall through to the note itself, which starts editing on the first click;
/// a background that took the click would only bring the window forward, so you'd have to click twice.
final class NoteSoftEdgeView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class NoteLiquidGlassView: NSGlassEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
