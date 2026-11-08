import AppKit
import SkywriteCore

enum MainMenu {
    static func build(appDelegate: AppDelegate, preferences: Preferences, updater: SoftwareUpdater) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        let about = appMenu.addItem(withTitle: String(localized: "About Skywrite"), action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
        about.target = appDelegate
        let updates = appMenu.addItem(withTitle: String(localized: "Check for Updates…"), action: #selector(SoftwareUpdater.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = updater
        appMenu.addItem(.separator())
        let settings = appMenu.addItem(withTitle: String(localized: "Settings…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        settings.target = appDelegate
        appMenu.addItem(.separator())
        let newNote = appMenu.addItem(withTitle: String(localized: "New Note"), action: #selector(AppDelegate.newNote(_:)), keyEquivalent: "")
        apply(preferences.shortcut(for: .newNote), to: newNote)
        newNote.target = appDelegate
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide Skywrite"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: String(localized: "Quit Skywrite"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Undo"), action: #selector(UndoActions.undo(_:)), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: String(localized: "Redo"), action: #selector(UndoActions.redo(_:)), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let reopen = editMenu.addItem(withTitle: String(localized: "Reopen Closed Note"), action: #selector(AppDelegate.reopenClosedNote(_:)), keyEquivalent: "")
        apply(preferences.shortcut(for: .reopenClosedNote), to: reopen)
        reopen.target = appDelegate
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let viewMenu = NSMenu(title: String(localized: "View"))
        let bigger = viewMenu.addItem(withTitle: String(localized: "Bigger Text"), action: #selector(AppDelegate.makeTextBigger(_:)), keyEquivalent: "+")
        bigger.target = appDelegate
        let smaller = viewMenu.addItem(withTitle: String(localized: "Smaller Text"), action: #selector(AppDelegate.makeTextSmaller(_:)), keyEquivalent: "-")
        smaller.target = appDelegate
        viewMenu.addItem(.separator())
        let toggle = viewMenu.addItem(withTitle: String(localized: "Show or Hide All Notes"), action: #selector(AppDelegate.toggleAllNotes(_:)), keyEquivalent: "")
        apply(preferences.shortcut(for: .toggleAllNotes), to: toggle)
        toggle.target = appDelegate
        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        return mainMenu
    }

    private static func apply(_ shortcut: Shortcut?, to item: NSMenuItem) {
        guard let shortcut else { return }
        item.keyEquivalent = shortcut.keyLabel.lowercased()
        item.keyEquivalentModifierMask = AppMenus.modifierFlags(shortcut.carbonModifiers)
    }
}

/// Names the standard Undo and Redo actions, which the text view and its undo manager answer through the responder
/// chain, so the menu can refer to them with #selector.
@objc private protocol UndoActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
}
