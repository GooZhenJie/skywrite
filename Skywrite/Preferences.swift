import AppKit
import Combine
import SkywriteCore

final class Preferences: ObservableObject {
    private let defaults: UserDefaults

    @Published var showsInDock: Bool { didSet { defaults.set(showsInDock, forKey: Key.showsInDock) } }
    @Published var showsInMenuBar: Bool { didSet { defaults.set(showsInMenuBar, forKey: Key.showsInMenuBar) } }
    @Published var tapKey: TapKey { didSet { defaults.set(tapKey.rawValue, forKey: Key.tapKey) } }
    @Published var fontSize: CGFloat { didSet { defaults.set(Double(fontSize), forKey: Key.fontSize) } }
    @Published var glassStyle: GlassStyle { didSet { defaults.set(glassStyle.rawValue, forKey: Key.glassStyle) } }
    @Published var glassStrength: Double { didSet { defaults.set(glassStrength, forKey: Key.glassStrength) } }
    @Published var liquidGlassStaysClear: Bool { didSet { defaults.set(liquidGlassStaysClear, forKey: Key.liquidGlassStaysClear) } }
    @Published var liquidGlassShadow: Bool { didSet { defaults.set(liquidGlassShadow, forKey: Key.liquidGlassShadow) } }
    @Published var darkTheme: Theme { didSet { defaults.set(darkTheme.rawValue, forKey: Key.darkTheme) } }
    @Published var lightTheme: Theme { didSet { defaults.set(lightTheme.rawValue, forKey: Key.lightTheme) } }
    @Published var notesFolderPath: String? { didSet { defaults.set(notesFolderPath, forKey: Key.notesFolderPath) } }
    @Published var noteRetention: NoteRetention { didSet { defaults.set(noteRetention.rawValue, forKey: Key.noteRetention) } }
    @Published var previewBackdrop: PreviewBackdrop { didSet { defaults.set(previewBackdrop.rawValue, forKey: Key.previewBackdrop) } }
    @Published var shortcuts: [ShortcutAction: Shortcut?] { didSet { saveShortcuts() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsInDock = defaults.object(forKey: Key.showsInDock) as? Bool ?? true
        showsInMenuBar = defaults.object(forKey: Key.showsInMenuBar) as? Bool ?? true
        defaults.removeObject(forKey: Key.removedClosesSettingsWhenInactive)
        defaults.removeObject(forKey: Key.removedNoteSpaces)
        // A Mac that already chose a key keeps it; a new install starts with pressing twice turned off.
        tapKey = defaults.string(forKey: Key.tapKey).flatMap(TapKey.init) ?? .off
        fontSize = (defaults.object(forKey: Key.fontSize) as? Double).map { CGFloat($0) } ?? NoteMetrics.baseFontSize
        let glass = GlassSetting(storedStyle: defaults.string(forKey: Key.glassStyle), storedStrength: defaults.object(forKey: Key.glassStrength) as? Double)
        glassStyle = glass.style
        glassStrength = glass.strength
        defaults.set(glass.style.rawValue, forKey: Key.glassStyle)
        defaults.set(glass.strength, forKey: Key.glassStrength)
        liquidGlassStaysClear = defaults.object(forKey: Key.liquidGlassStaysClear) as? Bool ?? true
        // Off to start with.
        liquidGlassShadow = defaults.object(forKey: Key.liquidGlassShadow) as? Bool ?? false
        // Starts on Ocean in Dark Mode. Nothing is stored until a theme is picked, so a Mac
        // that never picked one moves from Skywrite to Ocean too.
        darkTheme = Theme.stored(defaults.string(forKey: Key.darkTheme)) ?? .ocean
        let light = Theme.stored(defaults.string(forKey: Key.lightTheme)) ?? .skywriteLight
        lightTheme = light
        defaults.set(light.rawValue, forKey: Key.lightTheme)
        notesFolderPath = defaults.string(forKey: Key.notesFolderPath)
        noteRetention = (defaults.object(forKey: Key.noteRetention) as? Int).flatMap(NoteRetention.init) ?? .never
        // Starts on the blue sea photo. A Mac that chose "Your desktop picture", which is
        // gone now, reads nothing it knows and starts on the sea as well.
        previewBackdrop = defaults.string(forKey: Key.previewBackdrop).flatMap(PreviewBackdrop.init) ?? .sea
        shortcuts = Self.loadShortcuts(from: defaults)
    }

    /// Whether the menu bar menu has "New Grid Note". Grid notes are still being tried out, so the item is hidden unless
    /// it's turned on in Terminal, the way Rectangle and Maccy keep some settings out of their
    /// settings windows:
    ///
    ///     defaults write io.github.goozhenjie.skywrite showsNewGridNote -bool true
    ///
    /// Notes that already have cells open with them either way. Read each time the menu opens, so a change takes effect
    /// without restarting Skywrite.
    var showsNewGridNote: Bool {
        defaults.bool(forKey: Key.showsNewGridNote)
    }

    func shortcut(for action: ShortcutAction) -> Shortcut? {
        if let stored = shortcuts[action] {
            return stored
        }
        return action.defaultShortcut
    }

    func restoreDefaultShortcuts() {
        tapKey = .off
        shortcuts = [:]
    }

    func changeFontSize(by step: CGFloat) {
        fontSize = min(NoteMetrics.maximumFontSize, max(NoteMetrics.minimumFontSize, fontSize + step))
    }

    private func saveShortcuts() {
        let stored = shortcuts.reduce(into: [String: Data]()) { result, entry in
            result[entry.key.rawValue] = try? JSONEncoder().encode(entry.value)
        }
        defaults.set(stored, forKey: Key.shortcuts)
    }

    private static func loadShortcuts(from defaults: UserDefaults) -> [ShortcutAction: Shortcut?] {
        guard let stored = defaults.dictionary(forKey: Key.shortcuts) as? [String: Data] else { return [:] }
        return stored.reduce(into: [ShortcutAction: Shortcut?]()) { result, entry in
            guard let action = ShortcutAction(rawValue: entry.key), let value = try? JSONDecoder().decode(Shortcut?.self, from: entry.value) else { return }
            result[action] = .some(value)
        }
    }

    private enum Key {
        static let showsInDock = "showsInDock"
        static let showsInMenuBar = "showsInMenuBar"
        /// The switch "Close this window when you switch to another app" is gone, so its stored value is cleared. It only
        /// kept the settings window from jumping in front of other apps, which the window now does on its own.
        static let removedClosesSettingsWhenInactive = "closesSettingsWhenInactive"
        /// Older versions let you choose which desktops notes appear on; that setting is gone, so its stored value is cleared.
        static let removedNoteSpaces = "noteSpaces"
        static let tapKey = "tapKey"
        static let fontSize = "fontSize"
        static let glassStyle = "glassStyle"
        static let glassStrength = "glassStrength"
        static let liquidGlassStaysClear = "liquidGlassStaysClear"
        static let liquidGlassShadow = "liquidGlassShadow"
        static let darkTheme = "darkTheme"
        static let lightTheme = "lightTheme"
        static let notesFolderPath = "notesFolderPath"
        static let noteRetention = "noteRetentionDays"
        static let previewBackdrop = "previewBackdrop"
        static let shortcuts = "shortcuts"
        static let showsNewGridNote = "showsNewGridNote"
    }
}
