import Foundation

public struct NoteRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var fileName: String?
    public var isOnScreen: Bool
    public var topLeftX: Double
    public var topLeftY: Double
    public var fixedWidth: Double?
    public var minimumHeight: Double?
    public var zoom: Double
    public var createdAt: Date
    /// Pinned notes are listed first in the menus and are never moved to the Trash automatically.
    public var isPinned: Bool
    /// When the note was last closed; nil while it is on screen, and for notes closed by versions that didn't record it.
    public var closedAt: Date?

    public init(
        id: UUID = UUID(),
        fileName: String? = nil,
        isOnScreen: Bool = true,
        topLeftX: Double,
        topLeftY: Double,
        fixedWidth: Double? = nil,
        minimumHeight: Double? = nil,
        zoom: Double = 1,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        closedAt: Date? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.isOnScreen = isOnScreen
        self.topLeftX = topLeftX
        self.topLeftY = topLeftY
        self.fixedWidth = fixedWidth
        self.minimumHeight = minimumHeight
        self.zoom = zoom
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.closedAt = closedAt
    }

    /// Records saved before pinning existed have no isPinned, so it is read as false.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        isOnScreen = try container.decode(Bool.self, forKey: .isOnScreen)
        topLeftX = try container.decode(Double.self, forKey: .topLeftX)
        topLeftY = try container.decode(Double.self, forKey: .topLeftY)
        fixedWidth = try container.decodeIfPresent(Double.self, forKey: .fixedWidth)
        minimumHeight = try container.decodeIfPresent(Double.self, forKey: .minimumHeight)
        zoom = try container.decode(Double.self, forKey: .zoom)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
    }
}

extension Array where Element == NoteRecord {
    /// The list with each of `latest` put in place of the record with the same id, keeping the order; records that aren't in
    /// the list are ignored. Notes on screen change as you type and drag, so this folds their current state in before saving.
    public func updating(with latest: [NoteRecord]) -> [NoteRecord] {
        let byID = Dictionary(latest.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        return map { byID[$0.id] ?? $0 }
    }
}

struct NoteRecordFile: Codable {
    var version: Int
    var notes: [NoteRecord]
}
