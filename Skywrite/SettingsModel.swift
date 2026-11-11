import AppKit
import Combine
import SkywriteCore

final class SettingsModel: ObservableObject {
    enum Pane: String, CaseIterable, Identifiable {
        case general
        case appearance
        case shortcuts
        case storage
        case troubleshooting
        case uninstall
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: String(localized: "General")
            case .appearance: String(localized: "Appearance")
            case .shortcuts: String(localized: "Shortcuts")
            case .storage: String(localized: "Storage")
            case .troubleshooting: String(localized: "Troubleshooting")
            case .uninstall: String(localized: "Uninstall")
            case .about: String(localized: "About")
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            // A paint palette, as Chrome's settings use for Appearance (settings:palette in Chromium's settings_menu).
            case .appearance: "paintpalette.fill"
            case .shortcuts: "keyboard"
            case .storage: "folder"
            // A question mark, as Docker Desktop opens its Troubleshoot screen from a question mark icon
            // (docs.docker.com/desktop/troubleshoot-and-support/troubleshoot, read 2026-11-11).
            case .troubleshooting: "questionmark"
            // A page of its own with a trash can, as Karabiner-Elements' settings have an Uninstall page with the trash
            // symbol (SidebarItem.uninstall in src/apps/SettingsWindow/src/View/ContentMainView.swift, read 2026-11-11).
            case .uninstall: "trash"
            // Not shown: About uses Skywrite's own pen trail instead (see `showsAppMark`).
            case .about: "info"
            }
        }

        /// About shows Skywrite's own pen trail, the mark from the menu bar icon, the way System Settings shows your Mac
        /// on its About pane (ISSymbolName ISCurrentDevice on a gray tile, read from AboutExtension.appex on 2026-11-07)
        /// and Chrome shows its logo next to About Chrome (cr:chrome-product in Chromium's settings_menu.html.ts).
        var showsAppMark: Bool {
            self == .about
        }

        /// The section and setting names on this pane, so the sidebar search finds a pane by what's on it, not only by its title.
        /// Each name is matched in the app's language and in English.
        var searchNames: [String] {
            let keys: [String] = switch self {
            case .general:
                ["General", "Show Skywrite In", "Dock", "Menu bar", "Startup", "Open at login",
                 "Updates", "Check for updates automatically", "Check for Updates…", "Settings Window", "Close this window when you switch to another app"]
            case .appearance:
                ["Appearance", "Theme", "In Dark Mode", "In Light Mode", "Note Background", "Soft Edge", "Liquid Glass", "Strength",
                 "Stay clear when you’re not using the note", "Preview on", "Text", "Text size"]
            case .shortcuts:
                ["Shortcuts", "Global Shortcuts", "New note: press twice", "Restore Defaults"]
            case .storage:
                ["Storage", "Notes Folder", "Show in Finder", "Closed Notes", "Move to the Trash"]
            case .troubleshooting:
                ["Troubleshooting", "Logs", "Export Logs…"]
            case .uninstall:
                ["Uninstall", "Uninstall Skywrite", "Uninstall…"]
            case .about:
                ["About", "Check for Updates…", "Special Thanks", "Unsplash", "Canyon", "Dunes", "Mountains", "Sea", "City"]
            }
            let localized = keys.flatMap { [$0, String(localized: String.LocalizationValue($0))] }
            let extra: [String] = switch self {
            case .shortcuts: ShortcutAction.allCases.map(\.title) + TapKey.allCases.filter { $0 != .off }.map(\.title)
            case .about: PreviewBackdrop.allCases.map(\.credit.photographer)
            default: []
            }
            return localized + extra
        }

        var tint: NSColor {
            switch self {
            case .general: .systemGray
            case .appearance: .systemOrange
            case .shortcuts: .systemIndigo
            case .storage: .systemTeal
            case .troubleshooting: .systemGray
            // Red, like the Uninstall… button on the page.
            case .uninstall: .systemRed
            // The blue of the trail in the app icon (#2f74ec in AppIcon.icon/Assets/Trail.svg).
            case .about: NSColor(srgbRed: 0x2F / 255, green: 0x74 / 255, blue: 0xEC / 255, alpha: 1)
            }
        }
    }

    @Published var pane: Pane = .general {
        didSet {
            guard pane != oldValue, !isMovingThroughHistory else { return }
            history.visit(pane)
        }
    }
    @Published private(set) var history = NavigationHistory(Pane.general)
    private var isMovingThroughHistory = false
    @Published var opensAtLogin = LoginItem.isEnabled
    @Published var noteCount = 0
    @Published var notesFolder: URL
    @Published var errorMessage: String?
    @Published var recordingAction: ShortcutAction?
    @Published private(set) var isCollectingLogs = false

    let changeNotesFolder: (URL) throws -> Void
    /// Set by the app delegate; see `AppUninstaller`.
    var uninstall: (() -> Void)?
    let expiredNoteCount: (NoteRetention) -> Int

    init(notesFolder: URL, changeNotesFolder: @escaping (URL) throws -> Void, expiredNoteCount: @escaping (NoteRetention) -> Int) {
        self.notesFolder = notesFolder
        self.changeNotesFolder = changeNotesFolder
        self.expiredNoteCount = expiredNoteCount
    }

    func goBack() {
        history.goBack()
        show(history.current)
    }

    func goForward() {
        history.goForward()
        show(history.current)
    }

    private func show(_ target: Pane) {
        isMovingThroughHistory = true
        pane = target
        isMovingThroughHistory = false
    }

    /// A shorter period can move a batch of notes at once, so that only happens after you agree to the count.
    func confirmRetention(_ retention: NoteRetention) -> Bool {
        let count = expiredNoteCount(retention)
        guard count > 0 else { return true }
        let alert = NSAlert()
        alert.messageText = String(localized: "Move \(count) closed notes to the Trash?")
        alert.informativeText = String(localized: "They’ve been closed and unedited for longer than the time you chose. You can put them back from the Trash.")
        alert.addButton(withTitle: String(localized: "Move to Trash"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Reads Skywrite's log file and hides your home folder and user name off the main thread, then asks where to save
    /// the result. See `LogFile` and `LogExporter` for what goes in it.
    func exportLogs() {
        guard !isCollectingLogs else { return }
        isCollectingLogs = true
        EventLog.settings.notice("export logs started")
        Task { [weak self] in
            let text = await Task.detached(priority: .userInitiated) {
                LogExporter.collect().text(scrubber: LogExporter.scrubber)
            }.value
            guard let self else { return }
            isCollectingLogs = false
            EventLog.settings.notice("export logs collected characters=\(text.count, privacy: .public)")
            do {
                let window = NSApp.windows.first { $0.identifier?.rawValue == "settings" && $0.isVisible }
                let saved = try await LogExporter.save(text, attachedTo: window)
                EventLog.settings.notice("export logs saved=\(saved, privacy: .public)")
            } catch {
                EventLog.settings.error("export logs failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            errorMessage = error.localizedDescription
        }
        opensAtLogin = LoginItem.isEnabled
    }

    func chooseNotesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = notesFolder
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let folder = panel.url, folder.standardizedFileURL != notesFolder.standardizedFileURL else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Move your notes to “\(folder.lastPathComponent)”?")
        alert.informativeText = String(localized: "Skywrite will move all \(noteCount) notes into the new folder and save new notes there.")
        alert.addButton(withTitle: String(localized: "Move Notes"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try changeNotesFolder(folder)
            notesFolder = folder
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealNotesFolder() {
        try? FileManager.default.createDirectory(at: notesFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([notesFolder])
    }
}
