import Foundation

public struct NoteStore: Sendable {
    public let notesFolder: URL
    public let recordURL: URL

    public init(notesFolder: URL, recordURL: URL) {
        self.notesFolder = notesFolder
        self.recordURL = recordURL
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
        try FileManager.default.trashItem(at: fileURL(for: fileName), resultingItemURL: nil)
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
