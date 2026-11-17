import AppKit

extension NSScreen {
    /// The screen the pointer is on, or the main screen when it's on none (between screens, say).
    static var withPointer: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(mouse) } ?? main
    }
}
