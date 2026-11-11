import Foundation
import Testing
@testable import SkywriteCore

/// Moves "trashed" items into a folder of the test's own and refuses the names it's told to, so these tests never put
/// anything in your Trash.
private final class RecordingTrash: @unchecked Sendable {
    let folder: URL
    let refused: Set<String>
    private let lock = NSLock()
    private var trashed: [String] = []

    init(folder: URL, refusing refused: Set<String> = []) throws {
        self.folder = folder
        self.refused = refused
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    var trashedNames: [String] {
        lock.withLock { trashed }
    }

    func trash(_ url: URL) throws {
        let name = url.lastPathComponent
        if refused.contains(name) {
            throw CocoaError(.fileWriteNoPermission)
        }
        try FileManager.default.moveItem(at: url, to: folder.appending(path: UUID().uuidString + "-" + name))
        lock.withLock { trashed.append(name) }
    }
}

struct UninstallerTests {
    private let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "SkywriteCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func makeFile(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @Test func locationsMatchWhereTheAppWrites() {
        let home = URL(filePath: "/Users/someone", directoryHint: .isDirectory)
        let cache = URL(filePath: "/var/folders/ab/cd/C", directoryHint: .isDirectory)
        let locations = Uninstaller.Locations(home: home, bundleIdentifier: "io.github.goozhenjie.skywrite", systemCacheFolder: cache)
        #expect(locations.systemCache?.path == "/var/folders/ab/cd/C/io.github.goozhenjie.skywrite")
        #expect(locations.applicationSupport.path == "/Users/someone/Library/Application Support/io.github.goozhenjie.skywrite")
        #expect(locations.caches.path == "/Users/someone/Library/Caches/io.github.goozhenjie.skywrite")
        #expect(locations.httpStorage.path == "/Users/someone/Library/HTTPStorages/io.github.goozhenjie.skywrite")
        #expect(locations.savedState.path == "/Users/someone/Library/Saved Application State/io.github.goozhenjie.skywrite.savedState")
        #expect(locations.logs.path == "/Users/someone/Library/Logs/Skywrite")
        #expect(locations.all.last == locations.logs)
    }

    /// Matches what `getconf DARWIN_USER_CACHE_DIR` prints for this user.
    @Test func systemCacheFolderIsThePerUserCacheFolder() throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/getconf")
        process.arguments = ["DARWIN_USER_CACHE_DIR"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let printed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = try #require(Uninstaller.Locations.systemCacheFolder())
        #expect(folder.standardizedFileURL.path == URL(filePath: printed).standardizedFileURL.path)
    }

    /// The record file the app saves must sit inside the folder the uninstaller removes.
    @Test func applicationSupportHoldsTheNoteRecords() {
        let bundleIdentifier = "io.github.goozhenjie.skywrite"
        let store = NoteStore.standard(bundleIdentifier: bundleIdentifier)
        let locations = Uninstaller.Locations(home: FileManager.default.homeDirectoryForCurrentUser, bundleIdentifier: bundleIdentifier)
        #expect(store.recordURL.deletingLastPathComponent().standardizedFileURL.path == locations.applicationSupport.standardizedFileURL.path)
    }

    @Test func movesExistingItemsAndSkipsMissingOnes() throws {
        let trash = try RecordingTrash(folder: root.appending(path: "Trash"))
        let locations = Uninstaller.Locations(home: root, bundleIdentifier: "test.app", systemCacheFolder: root.appending(path: "C"))
        try makeFile(locations.applicationSupport.appending(path: "notes.json"))
        try makeFile(locations.logs.appending(path: "Skywrite.log"))
        let systemCache = try #require(locations.systemCache)
        try makeFile(systemCache.appending(path: "com.apple.metal/libraries.data"))
        let leftBehind = Uninstaller(trash: trash.trash).moveToTrash(locations.all)
        #expect(leftBehind.isEmpty)
        #expect(trash.trashedNames == ["test.app", "test.app", "Skywrite"])
        #expect(!exists(locations.applicationSupport))
        #expect(!exists(systemCache))
        #expect(!exists(locations.logs))
    }

    @Test func reportsWhatItCouldNotMoveAndKeepsGoing() throws {
        let trash = try RecordingTrash(folder: root.appending(path: "Trash"), refusing: ["test.app"])
        let locations = Uninstaller.Locations(home: root, bundleIdentifier: "test.app", systemCacheFolder: root.appending(path: "C"))
        try makeFile(locations.applicationSupport.appending(path: "notes.json"))
        try makeFile(locations.caches.appending(path: "cache"))
        try makeFile(locations.logs.appending(path: "Skywrite.log"))
        let leftBehind = Uninstaller(trash: trash.trash).moveToTrash(locations.all)
        #expect(leftBehind == [locations.applicationSupport, locations.caches])
        #expect(trash.trashedNames == ["Skywrite"])
    }

    @Test func movesNotesAndTheirFolderWhenNothingElseIsInIt() throws {
        let trash = try RecordingTrash(folder: root.appending(path: "Trash"))
        let folder = root.appending(path: "Skywrite", directoryHint: .isDirectory)
        try makeFile(folder.appending(path: "a.md"))
        try makeFile(folder.appending(path: "b.md"))
        try makeFile(folder.appending(path: ".DS_Store"))
        let leftBehind = Uninstaller(trash: trash.trash).moveNotesToTrash(fileNames: ["a.md", "b.md"], in: folder)
        #expect(leftBehind.isEmpty)
        #expect(trash.trashedNames == ["a.md", "b.md", "Skywrite"])
        #expect(!exists(folder))
    }

    /// Notes left in the folder after a reinstall count too, but only files named the way Skywrite names notes.
    @Test func findsNotesTheRecordNoLongerLists() throws {
        let folder = root.appending(path: "Skywrite", directoryHint: .isDirectory)
        for name in ["2026-11-03 17.19.30.md", "2026-11-03 17.19.30 2.md", "2026-11-11 13.32.11.md", "Skywrite Logs 2026-11-07 1612.txt", "Shopping.md", "2026-11-03.md", ".DS_Store"] {
            try makeFile(folder.appending(path: name))
        }
        let names = Uninstaller.noteFileNames(known: ["2026-11-11 13.32.11.md", "gone.md"], in: folder)
        #expect(names == ["2026-11-11 13.32.11.md", "gone.md", "2026-11-03 17.19.30 2.md", "2026-11-03 17.19.30.md"])
        #expect(Uninstaller.noteFileNames(known: [], in: root.appending(path: "Missing")).isEmpty)
    }

    /// A notes folder you chose yourself, such as Documents, keeps everything that isn't a Skywrite note.
    @Test func leavesOtherFilesAndTheFolderAlone() throws {
        let trash = try RecordingTrash(folder: root.appending(path: "Trash"))
        let folder = root.appending(path: "Documents", directoryHint: .isDirectory)
        try makeFile(folder.appending(path: "a.md"))
        try makeFile(folder.appending(path: "Tax return.pdf"))
        let leftBehind = Uninstaller(trash: trash.trash).moveNotesToTrash(fileNames: ["a.md", "gone.md"], in: folder)
        #expect(leftBehind.isEmpty)
        #expect(trash.trashedNames == ["a.md"])
        #expect(exists(folder.appending(path: "Tax return.pdf")))
    }

    @Test func keepsTheFolderWhenANoteCouldNotBeMoved() throws {
        let trash = try RecordingTrash(folder: root.appending(path: "Trash"), refusing: ["b.md"])
        let folder = root.appending(path: "Skywrite", directoryHint: .isDirectory)
        try makeFile(folder.appending(path: "a.md"))
        try makeFile(folder.appending(path: "b.md"))
        let leftBehind = Uninstaller(trash: trash.trash).moveNotesToTrash(fileNames: ["a.md", "b.md"], in: folder)
        #expect(leftBehind == [folder.appending(path: "b.md")])
        #expect(exists(folder.appending(path: "b.md")))
    }

    /// Uses the real preferences service on a domain of the test's own. It always uses the same name: the service writes
    /// an empty file back for a cleared domain, so a new name each run would leave one more file in ~/Library/Preferences.
    @Test func clearingPreferencesRemovesEverySetting() throws {
        let domain = "SkywriteCoreTests-Uninstaller"
        let name = domain as CFString
        CFPreferencesSetAppValue("fontSize" as CFString, 21 as CFNumber, name)
        CFPreferencesSetAppValue("lightTheme" as CFString, "meadow" as CFString, name)
        CFPreferencesAppSynchronize(name)

        let remaining = Uninstaller().clearPreferences(domain: domain)

        #expect(remaining.isEmpty)
        #expect(CFPreferencesCopyAppValue("fontSize" as CFString, name) == nil)
        #expect(UserDefaults(suiteName: domain)?.object(forKey: "lightTheme") == nil)
    }
}
