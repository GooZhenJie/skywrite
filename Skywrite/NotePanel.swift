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
        // Notes follow you to every desktop and over full-screen apps, the way Snipaste pins do (user decision 2026-11-06).
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

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
