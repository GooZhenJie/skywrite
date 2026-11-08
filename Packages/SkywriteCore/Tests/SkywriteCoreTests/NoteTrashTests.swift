import Foundation
import Testing
@testable import SkywriteCore

/// Stands in for the Trash: it moves files into a folder of the test's own and can be told to refuse some, so these tests
/// never put anything in your Trash.
private final class FakeTrash: @unchecked Sendable {
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

struct NoteTrashTests {
    private let root: URL
    private let day: TimeInterval = 24 * 60 * 60
    private let now = Date()

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "SkywriteCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func makeStore(_ fakeTrash: FakeTrash) -> NoteStore {
        NoteStore(notesFolder: root.appending(path: "Notes"), recordURL: root.appending(path: "notes.json"), trash: fakeTrash.trash)
    }

    /// Writes a note file last edited `editedDaysAgo` days ago and returns its record.
    private func note(
        _ fileName: String,
        in store: NoteStore,
        editedDaysAgo: Double,
        isOnScreen: Bool = false,
        isPinned: Bool = false
    ) throws -> NoteRecord {
        try store.writeText("text of \(fileName)", to: fileName)
        let edited = now.addingTimeInterval(-editedDaysAgo * day)
        try FileManager.default.setAttributes([.modificationDate: edited], ofItemAtPath: store.fileURL(for: fileName).path)
        return NoteRecord(
            fileName: fileName,
            isOnScreen: isOnScreen,
            topLeftX: 0,
            topLeftY: 0,
            createdAt: now.addingTimeInterval(-400 * day),
            isPinned: isPinned,
            closedAt: isOnScreen ? nil : edited
        )
    }

    @Test func movesOnlyClosedUnpinnedNotesLeftAloneForThePeriod() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"))
        let store = makeStore(fakeTrash)
        let old = try note("old.md", in: store, editedDaysAgo: 30)
        let pinned = try note("pinned.md", in: store, editedDaysAgo: 30, isPinned: true)
        let onScreen = try note("on-screen.md", in: store, editedDaysAgo: 30, isOnScreen: true)
        let shown = try note("shown.md", in: store, editedDaysAgo: 30)
        let fresh = try note("fresh.md", in: store, editedDaysAgo: 2)
        let records = [old, pinned, onScreen, shown, fresh]

        let expired = store.expiredNotes(in: records, retention: .oneWeek, now: now, shownIDs: [shown.id])
        let result = store.moveNotesToTrash(expired)

        #expect(expired.map(\.fileName) == ["old.md"])
        #expect(result.removedIDs == [old.id])
        #expect(result.movedCount == 1)
        #expect(result.errors.isEmpty)
        #expect(fakeTrash.trashedNames == ["old.md"])
        #expect(!store.fileExists("old.md"))
        for kept in ["pinned.md", "on-screen.md", "shown.md", "fresh.md"] {
            #expect(store.fileExists(kept))
        }
    }

    @Test func neverMovesNothingEvenForAncientNotes() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"))
        let store = makeStore(fakeTrash)
        let ancient = try note("ancient.md", in: store, editedDaysAgo: 3000)
        #expect(store.expiredNotes(in: [ancient], retention: .never, now: now).isEmpty)
    }

    @Test func aFileThatCannotBeMovedKeepsItsNoteAndTheOthersStillMove() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"), refusing: ["b.md"])
        let store = makeStore(fakeTrash)
        let first = try note("a.md", in: store, editedDaysAgo: 30)
        let refused = try note("b.md", in: store, editedDaysAgo: 30)
        let third = try note("c.md", in: store, editedDaysAgo: 30)

        let result = store.moveNotesToTrash([first, refused, third])

        #expect(result.removedIDs == [first.id, third.id])
        #expect(result.movedCount == 2)
        #expect(result.errors.count == 1)
        #expect(fakeTrash.trashedNames == ["a.md", "c.md"])
        #expect(store.fileExists("b.md"))
    }

    @Test func aNoteWhoseFileIsAlreadyGoneComesOffTheListWithoutBeingCounted() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"))
        let store = makeStore(fakeTrash)
        let gone = NoteRecord(fileName: "deleted-in-finder.md", isOnScreen: false, topLeftX: 0, topLeftY: 0)

        let result = store.moveNotesToTrash([gone])

        #expect(result.removedIDs == [gone.id])
        #expect(result.movedCount == 0)
        #expect(fakeTrash.trashedNames.isEmpty)
    }

    @Test func aNoteThatNeverHadAFileIsLeftAlone() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"))
        let store = makeStore(fakeTrash)
        let result = store.moveNotesToTrash([NoteRecord(isOnScreen: false, topLeftX: 0, topLeftY: 0)])
        #expect(result.removedIDs.isEmpty)
        #expect(result.movedCount == 0)
    }

    @Test func deletingOneNoteUsesTheSameTrash() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"))
        let store = makeStore(fakeTrash)
        try store.writeText("bye", to: "x.md")
        try store.moveToTrash("x.md")
        #expect(fakeTrash.trashedNames == ["x.md"])
        #expect(!store.fileExists("x.md"))
    }

    @Test func notesMovedToAnotherFolderStillGoToTheSameTrash() throws {
        let fakeTrash = try FakeTrash(folder: root.appending(path: "Trash"))
        let store = makeStore(fakeTrash)
        try store.writeText("moving", to: "y.md")
        let moved = try store.movingNotes(["y.md"], to: root.appending(path: "Elsewhere")).store
        try moved.moveToTrash("y.md")
        #expect(fakeTrash.trashedNames == ["y.md"])
    }
}
