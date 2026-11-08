import AppKit
import SkywriteCore

final class AppMenus: NSObject, NSMenuDelegate {
    private weak var appDelegate: AppDelegate?
    private let noteManager: NoteManager
    private let preferences: Preferences
    private let updater: SoftwareUpdater
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter
    }()

    init(appDelegate: AppDelegate, noteManager: NoteManager, preferences: Preferences, updater: SoftwareUpdater) {
        self.appDelegate = appDelegate
        self.noteManager = noteManager
        self.preferences = preferences
        self.updater = updater
    }

    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.identifier = NSUserInterfaceItemIdentifier("status")
        return menu
    }

    func makeDockMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(String(localized: "New Note"), #selector(AppDelegate.newNote(_:)), symbol: "square.and.pencil"))
        menu.addItem(.separator())
        addRecent(to: menu)
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        appDelegate?.statusMenuWillOpen(menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        appDelegate?.statusMenuDidClose(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item(String(localized: "New Note"), #selector(AppDelegate.newNote(_:)), symbol: "square.and.pencil", shortcut: preferences.shortcut(for: .newNote)))
        let toggleTitle = noteManager.areNotesHidden ? String(localized: "Show All Notes") : String(localized: "Hide All Notes")
        let toggle = item(toggleTitle, #selector(AppDelegate.toggleAllNotes(_:)), symbol: noteManager.areNotesHidden ? "eye" : "eye.slash", shortcut: preferences.shortcut(for: .toggleAllNotes))
        menu.addItem(toggle)
        menu.addItem(item(String(localized: "Reopen Closed Note"), #selector(AppDelegate.reopenClosedNote(_:)), symbol: "arrow.uturn.backward", shortcut: preferences.shortcut(for: .reopenClosedNote)))
        if noteManager.hasNotesOffScreen {
            menu.addItem(item(String(localized: "Move Notes Back on Screen"), #selector(AppDelegate.moveNotesBackOnScreen(_:)), symbol: "rectangle.portrait.and.arrow.right"))
        }
        menu.addItem(.separator())
        addRecent(to: menu)
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Open Notes Folder"), #selector(AppDelegate.openNotesFolder(_:)), symbol: "folder"))
        let settings = item(String(localized: "Settings…"), #selector(AppDelegate.showSettings(_:)), symbol: "gearshape")
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = .command
        menu.addItem(settings)
        let updates = item(String(localized: "Check for Updates…"), #selector(SoftwareUpdater.checkForUpdates(_:)), symbol: "arrow.down.circle")
        updates.target = updater
        menu.addItem(updates)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: String(localized: "Quit Skywrite"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    /// Pinned notes come first in a section of their own, like Raycast's clipboard history; "Recent" lists the rest.
    private func addRecent(to menu: NSMenu) {
        let notes = noteManager.menuNotes()
        if !notes.pinned.isEmpty {
            menu.addItem(.sectionHeader(title: String(localized: "Pinned")))
            notes.pinned.forEach { menu.addItem(entry(for: $0)) }
            guard !notes.recent.isEmpty else { return }
        }
        menu.addItem(.sectionHeader(title: String(localized: "Recent")))
        guard !notes.recent.isEmpty else {
            let empty = NSMenuItem(title: String(localized: "No notes yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        notes.recent.forEach { menu.addItem(entry(for: $0)) }
    }

    private func entry(for note: RecentNote) -> NSMenuItem {
        let entry = NSMenuItem(title: note.title, action: #selector(AppDelegate.showRecentNote(_:)), keyEquivalent: "")
        entry.target = appDelegate
        entry.representedObject = note.id
        entry.state = note.isOnScreen ? .on : .off
        entry.subtitle = relativeFormatter.localizedString(for: min(note.modifiedAt, Date()), relativeTo: Date())
        return entry
    }

    private func item(_ title: String, _ action: Selector, symbol: String, shortcut: Shortcut? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = appDelegate
        entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        if let shortcut {
            entry.keyEquivalent = shortcut.keyLabel.lowercased()
            entry.keyEquivalentModifierMask = Self.modifierFlags(shortcut.carbonModifiers)
        }
        return entry
    }

    static func modifierFlags(_ carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & Shortcut.controlFlag != 0 { flags.insert(.control) }
        if carbonModifiers & Shortcut.optionFlag != 0 { flags.insert(.option) }
        if carbonModifiers & Shortcut.shiftFlag != 0 { flags.insert(.shift) }
        if carbonModifiers & Shortcut.commandFlag != 0 { flags.insert(.command) }
        return flags
    }
}
