import AppKit
import SkywriteCore
import SwiftUI

/// The panel the Search Notes shortcut opens near the top of the screen: type to find a note, Return puts it back on screen.
///
/// It takes typing without bringing Skywrite to the front, the way Maccy's history panel does (a non-activating panel that
/// becomes key: Maccy's FloatingPanel). So the app you were in stays in front, and an open settings window stays where it
/// was instead of coming forward with Skywrite.
final class QuickPanelWindow: NSPanel {
    var onResignKey: (() -> Void)?

    init() {
        let size = NSSize(width: NoteMetrics.quickPanelWidth, height: NoteMetrics.quickPanelHeight)
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        // Above the notes (.floating), so a note never covers the panel.
        level = .statusBar
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        // Opens on the desktop you're on and over full-screen apps, like Maccy's panel.
        collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        identifier = NSUserInterfaceItemIdentifier("quick-panel")
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Clicking anywhere else takes the keyboard away from the panel, and that closes it.
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    /// The glass keeps the look it has in a window you're using: the panel is only ever on screen while you use it.
    /// Same undocumented AppKit question NotePanel answers.
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { // swiftlint:disable:this identifier_name - AppKit's own name
        true
    }
}

final class QuickPanelController {
    private let panel = QuickPanelWindow()
    private let model = QuickPanelModel()
    private let noteManager: NoteManager
    private let preferences: Preferences
    private var isShown = false
    private var clickMonitor: Any?

    init(noteManager: NoteManager, preferences: Preferences) {
        self.noteManager = noteManager
        self.preferences = preferences
        model.open = { [weak self] id in
            self?.showNote(id)
        }
        model.close = { [weak self] in
            self?.close()
        }
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = NoteMetrics.quickPanelCornerRadius
        glass.contentView = NSHostingView(rootView: QuickPanelView(model: model).environmentObject(preferences))
        // Cut to its rounded shape, so the glass's own shadow doesn't leave dark corners and edges at the panel's square
        // edges; see `GlassClipView`.
        let clip = GlassClipView(frame: NSRect(origin: .zero, size: panel.frame.size))
        clip.layer?.cornerRadius = NoteMetrics.quickPanelCornerRadius
        glass.frame = clip.bounds
        glass.autoresizingMask = [.width, .height]
        clip.addSubview(glass)
        panel.contentView = clip
        panel.onResignKey = { [weak self] in
            self?.close(handingFrontBack: false)
        }
    }

    func toggle() {
        if isShown {
            close()
        } else {
            open()
        }
    }

    func open() {
        guard !isShown else { return }
        isShown = true
        model.newNoteShortcut = preferences.shortcut(for: .newNote)
        model.reload(noteManager.searchableNotes())
        place()
        panel.orderFrontRegardless()
        panel.makeKey()
        // The first time, SwiftUI makes the search field during this layout; without it there'd be no field to type in yet.
        panel.contentView?.layoutSubtreeIfNeeded()
        model.focusSearchField()
        watchClicksInOtherApps()
        EventLog.windows.notice("quick panel opened notes=\(self.model.notes.count, privacy: .public) appActive=\(NSApp.isActive, privacy: .public)")
    }

    /// `handingFrontBack` is false when you clicked somewhere else: the app you clicked comes to the front by itself, and
    /// handing the front to the app you were in before could win over it.
    func close(handingFrontBack: Bool = true) {
        guard isShown else { return }
        isShown = false
        stopWatchingClicks()
        // Closing it with Esc or Return while you were typing in a note goes back to the app you came from, the same way
        // closing that note does, so AppKit has no settings window to make key and bring forward.
        if handingFrontBack, panel.isKeyWindow, NSApp.isActive {
            NSApp.leaveClosingNote()
        }
        panel.orderOut(nil)
        EventLog.windows.notice("quick panel closed")
    }

    private func showNote(_ id: UUID) {
        EventLog.notes.notice("quick panel shows note \(id.uuidString.prefix(8), privacy: .public)")
        close()
        noteManager.showNote(id)
    }

    /// Centered on the screen with the pointer, its top a little below the top of the screen.
    private func place() {
        guard let screen = NSScreen.withPointer else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: NoteMetrics.quickPanelWidth, height: NoteMetrics.quickPanelHeight)
        let top = visible.maxY - visible.height * NoteMetrics.quickPanelTopShare
        let origin = NSPoint(x: (visible.midX - size.width / 2).rounded(), y: max(visible.minY, top - size.height).rounded())
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    /// A click in another app doesn't always take the keyboard from a panel that never brought Skywrite to the front,
    /// so clicks there close it too. Watching other apps' clicks needs no permission; only their keys would.
    private func watchClicksInOtherApps() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.close(handingFrontBack: false)
            }
        }
    }

    private func stopWatchingClicks() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
    }
}

final class QuickPanelModel: ObservableObject {
    @Published private(set) var notes: [SearchableNote] = []
    @Published var query = "" {
        didSet { if query != oldValue, !isReloading { refresh() } }
    }
    @Published var filter: NoteFilter = .all {
        didSet { if filter != oldValue, !isReloading { refresh() } }
    }
    @Published private(set) var sections: [NoteSection] = []
    /// Every row in the list, in order: the sections without their headings.
    private(set) var matches: [NoteMatch] = []
    private var isReloading = false
    @Published var selection: UUID?
    @Published var newNoteShortcut: Shortcut?
    private(set) var now = Date()
    weak var searchField: NSTextField?
    var open: (UUID) -> Void = { _ in }
    var close: () -> Void = {}

    var selectedMatch: NoteMatch? {
        matches.first { $0.id == selection }
    }

    var terms: [String] {
        NoteSearch.terms(in: query)
    }

    /// Starts over each time the panel opens: nothing typed, every note, the first one picked.
    func reload(_ notes: [SearchableNote]) {
        isReloading = true
        self.notes = notes
        now = Date()
        query = ""
        filter = .all
        isReloading = false
        searchField?.stringValue = ""
        refresh()
    }

    func moveSelection(by offset: Int) {
        let ids = matches.map(\.id)
        guard !ids.isEmpty else { return }
        let current = selection.flatMap(ids.firstIndex(of:)) ?? 0
        selection = ids[min(max(current + offset, 0), ids.count - 1)]
    }

    func openSelection() {
        guard let selection else { return }
        open(selection)
    }

    func focusSearchField() {
        guard let searchField, let window = searchField.window else {
            EventLog.windows.notice("quick panel search field not in a window yet")
            return
        }
        if window.firstResponder != searchField.currentEditor() {
            window.makeFirstResponder(searchField)
        }
        searchField.currentEditor()?.selectedRange = NSRange(location: searchField.stringValue.utf16.count, length: 0)
    }

    private func refresh() {
        let sections = NoteSearch.sections(for: notes, query: query, filter: filter, now: now)
        matches = sections.flatMap(\.matches)
        self.sections = sections
        selection = matches.first?.id
    }
}
