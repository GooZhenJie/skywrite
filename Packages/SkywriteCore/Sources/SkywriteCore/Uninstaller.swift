import Foundation

/// What "Uninstall Skywrite…" removes, and the part of it that moves files to the Trash.
///
/// Dragging an app to the Trash leaves everything it saved in ~/Library behind, so reinstalling brings the old settings
/// back. Apple suggests an app's own uninstaller as the way to remove that too (support.apple.com/102610, read
/// 2026-11-10), and Zoom and AnyDesk put one in their menus. Files go to the Trash rather than being deleted, so you can
/// put them back; the settings are cleared through the preferences service, which keeps them, so they can't.
public struct Uninstaller: Sendable {
    /// The folders Skywrite and the frameworks it uses write to, for an app with this bundle identifier.
    public struct Locations: Sendable, Equatable {
        /// notes.json: where each note sits on screen, its size and whether it's locked.
        public var applicationSupport: URL
        /// Sparkle's downloads and the system's network cache for update checks.
        public var caches: URL
        public var httpStorage: URL
        /// The window positions macOS restores at launch, if it ever saved any for Skywrite.
        public var savedState: URL
        /// Skywrite.log, the file Export Logs… copies.
        public var logs: URL
        /// The Metal shader cache macOS keeps for each app that draws with the graphics card, in the per-user cache
        /// folder under /var/folders (`getconf DARWIN_USER_CACHE_DIR`). Found after the first real uninstall on
        /// 2026-11-11: io.github.goozhenjie.skywrite/com.apple.metal, 368 KB, was the only folder of Skywrite's left.
        public var systemCache: URL?

        public init(home: URL, bundleIdentifier: String, systemCacheFolder: URL? = Locations.systemCacheFolder()) {
            let library = home.appending(path: "Library", directoryHint: .isDirectory)
            applicationSupport = library.appending(path: "Application Support/\(bundleIdentifier)", directoryHint: .isDirectory)
            caches = library.appending(path: "Caches/\(bundleIdentifier)", directoryHint: .isDirectory)
            httpStorage = library.appending(path: "HTTPStorages/\(bundleIdentifier)", directoryHint: .isDirectory)
            savedState = library.appending(path: "Saved Application State/\(bundleIdentifier).savedState", directoryHint: .isDirectory)
            logs = library.appending(path: "Logs/Skywrite", directoryHint: .isDirectory)
            systemCache = systemCacheFolder?.appending(path: bundleIdentifier, directoryHint: .isDirectory)
        }

        /// The logs come last, so whatever happens before still gets written to them.
        public var all: [URL] {
            [applicationSupport, caches, httpStorage, savedState] + (systemCache.map { [$0] } ?? []) + [logs]
        }

        /// This user's cache folder under /var/folders, the one `getconf DARWIN_USER_CACHE_DIR` prints.
        public static func systemCacheFolder() -> URL? {
            let length = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
            guard length > 0 else { return nil }
            var buffer = [CChar](repeating: 0, count: length)
            guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, length) > 0 else { return nil }
            let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            guard let path = String(bytes: bytes, encoding: .utf8) else { return nil }
            return URL(filePath: path, directoryHint: .isDirectory)
        }
    }

    public let trash: @Sendable (URL) throws -> Void

    public init(trash: @escaping @Sendable (URL) throws -> Void = NoteStore.moveToSystemTrash) {
        self.trash = trash
    }

    /// Moves each item that exists to the Trash and returns the ones it couldn't move. Items that aren't there are
    /// skipped, since most Macs never get a saved state folder, for example.
    public func moveToTrash(_ items: [URL]) -> [URL] {
        items.filter { item in
            guard FileManager.default.fileExists(atPath: item.path) else { return false }
            do {
                try trash(item)
                return false
            } catch {
                return true
            }
        }
    }

    /// Clears every setting in this preferences domain and waits until the preferences service has taken that in.
    /// Returns the names of any settings still there afterwards.
    ///
    /// The settings file itself stays, empty. Measured on 2026-11-10 with a test domain: after the settings were cleared
    /// and the file was moved away, the preferences service wrote an empty file back within seconds; `defaults delete`
    /// and `UserDefaults.removePersistentDomain(forName:)` leave an empty file too. Moving it to the Trash would only put
    /// a stale copy there, since the service writes the file later than `CFPreferencesAppSynchronize` returns.
    @discardableResult
    public func clearPreferences(domain: String) -> [String] {
        let name = domain as CFString
        let keys = (CFPreferencesCopyKeyList(name, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]) ?? []
        for key in keys {
            CFPreferencesSetAppValue(key as CFString, nil, name)
        }
        CFPreferencesAppSynchronize(name)
        return (CFPreferencesCopyKeyList(name, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]) ?? []
    }

    /// The notes Skywrite knows about plus any file in the folder named the way Skywrite names notes
    /// ("2026-11-03 17.19.30.md", or "… 2.md" for a second note in the same second; see `NoteStore.makeFileName`).
    /// After an uninstall that kept the notes and a reinstall, notes.json is gone, so the record alone lists none of
    /// them (2026-11-11: 55 notes in ~/Documents/Skywrite, 0 in the record). Other files in the folder are never listed.
    public static func noteFileNames(known: [String], in folder: URL) -> [String] {
        let pattern = /^\d{4}-\d{2}-\d{2} \d{2}\.\d{2}\.\d{2}( \d+)?\.md$/
        let named = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.wholeMatch(of: pattern) != nil }
        var seen = Set<String>()
        return (known + named.sorted()).filter { seen.insert($0).inserted }
    }

    /// Moves Skywrite's own note files to the Trash, then the folder only if nothing else is left in it. The notes folder
    /// can be one you chose, such as Documents or the Desktop, so other files in it are never touched.
    public func moveNotesToTrash(fileNames: [String], in folder: URL) -> [URL] {
        let leftBehind = moveToTrash(fileNames.map { folder.appending(path: $0) })
        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        // Finder's .DS_Store doesn't count as something you put there.
        guard leftBehind.isEmpty, remaining.allSatisfy({ $0 == ".DS_Store" }) else { return leftBehind }
        return moveToTrash([folder])
    }
}
