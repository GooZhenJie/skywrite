import Foundation

public struct NoteStore: Sendable {
    public let notesFolder: URL
    public let recordURL: URL
    /// Puts a file in the Trash. The app always uses the system Trash; tests pass their own, so a test run never puts
    /// files in your Trash.
    public let trash: @Sendable (URL) throws -> Void

    public init(notesFolder: URL, recordURL: URL, trash: @escaping @Sendable (URL) throws -> Void = NoteStore.moveToSystemTrash) {
        self.notesFolder = notesFolder
        self.recordURL = recordURL
        self.trash = trash
    }

    public static func moveToSystemTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public static func standard(bundleIdentifier: String) -> NoteStore {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return NoteStore(
            notesFolder: documents.appendingPathComponent("Skywrite", isDirectory: true),
            recordURL: support.appendingPathComponent(bundleIdentifier, isDirectory: true).appendingPathComponent("notes.json")
        )
    }

    public func loadRecords() throws -> [NoteRecord] {
        guard FileManager.default.fileExists(atPath: recordURL.path) else { return [] }
        let data = try Data(contentsOf: recordURL)
        return try Self.decoder.decode(NoteRecordFile.self, from: data).notes
    }

    public func saveRecords(_ records: [NoteRecord]) throws {
        try FileManager.default.createDirectory(at: recordURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encoder.encode(NoteRecordFile(version: 1, notes: records.filter { $0.fileName != nil }))
        try data.write(to: recordURL, options: .atomic)
    }

    public func fileURL(for fileName: String) -> URL {
        notesFolder.appendingPathComponent(fileName)
    }

    public func fileExists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    public func readText(_ fileName: String) throws -> String {
        try String(contentsOf: fileURL(for: fileName), encoding: .utf8)
    }

    public func writeText(_ text: String, to fileName: String) throws {
        try FileManager.default.createDirectory(at: notesFolder, withIntermediateDirectories: true)
        try text.write(to: fileURL(for: fileName), atomically: true, encoding: .utf8)
    }

    public func moveToTrash(_ fileName: String) throws {
        guard fileExists(fileName) else { return }
        try trash(fileURL(for: fileName))
    }

    public func modificationDate(of fileName: String) -> Date? {
        try? fileURL(for: fileName).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    public func movingNotes(_ fileNames: [String], to newFolder: URL) throws -> (store: NoteStore, renamed: [String: String]) {
        let destination = NoteStore(notesFolder: newFolder, recordURL: recordURL, trash: trash)
        guard newFolder.standardizedFileURL != notesFolder.standardizedFileURL else { return (destination, [:]) }
        try FileManager.default.createDirectory(at: newFolder, withIntermediateDirectories: true)
        var renamed: [String: String] = [:]
        for fileName in fileNames where fileExists(fileName) {
            let target = destination.freeName(for: fileName)
            try FileManager.default.moveItem(at: fileURL(for: fileName), to: destination.fileURL(for: target))
            if target != fileName {
                renamed[fileName] = target
            }
        }
        return (destination, renamed)
    }

    func freeName(for fileName: String) -> String {
        guard fileExists(fileName) else { return fileName }
        let url = URL(fileURLWithPath: fileName)
        let stem = url.deletingPathExtension().lastPathComponent
        let suffix = url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)"
        var copy = 2
        while fileExists("\(stem) \(copy)\(suffix)") {
            copy += 1
        }
        return "\(stem) \(copy)\(suffix)"
    }

    /// The file a note's text goes to: its own file, or, once a note without one has any text, a new file named after when
    /// the note was made. Returns nil while a new note is still empty, so an empty note leaves no file behind.
    public func fileName(forSaving text: String, existing fileName: String?, createdAt: Date, timeZone: TimeZone = .current) -> String? {
        if let fileName {
            return fileName
        }
        return text.isEmpty ? nil : makeFileName(createdAt: createdAt, timeZone: timeZone)
    }

    public func makeFileName(createdAt: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let stem = formatter.string(from: createdAt)
        var candidate = "\(stem).md"
        var copy = 2
        while fileExists(candidate) {
            candidate = "\(stem) \(copy).md"
            copy += 1
        }
        return candidate
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
