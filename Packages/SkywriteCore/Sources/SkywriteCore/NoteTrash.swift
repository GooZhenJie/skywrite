import Foundation

/// What moving notes to the Trash did.
public struct NoteTrashResult: Sendable {
    /// Notes to take off the list: their file went to the Trash, or was already gone.
    public var removedIDs: [UUID]
    /// How many files actually went to the Trash.
    public var movedCount: Int
    /// Files that couldn't be moved. Their notes stay on the list, so no note disappears without its file being in the Trash.
    public var errors: [any Error]
}

extension NoteStore {
    /// Closed notes left alone for the whole retention period (see `NoteRetention.expired`), judged by each file's last edit.
    /// Notes in `shownIDs` are skipped even if their record says closed, so a note on screen is never moved.
    public func expiredNotes(in records: [NoteRecord], retention: NoteRetention, now: Date, shownIDs: Set<UUID> = []) -> [NoteRecord] {
        retention.expired(records, now: now, modifiedAt: { $0.fileName.flatMap(modificationDate(of:)) })
            .filter { !shownIDs.contains($0.id) }
    }

    /// Moves the notes' files to the Trash, the same way deleting a note does. Each note is tried on its own, so a file that
    /// can't be moved doesn't stop the rest.
    public func moveNotesToTrash(_ records: [NoteRecord]) -> NoteTrashResult {
        var result = NoteTrashResult(removedIDs: [], movedCount: 0, errors: [])
        for record in records {
            guard let fileName = record.fileName else { continue }
            if fileExists(fileName) {
                do {
                    try moveToTrash(fileName)
                    result.movedCount += 1
                } catch {
                    result.errors.append(error)
                    continue
                }
            }
            result.removedIDs.append(record.id)
        }
        return result
    }
}
