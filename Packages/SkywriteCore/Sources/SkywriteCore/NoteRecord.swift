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

    public init(
        id: UUID = UUID(),
        fileName: String? = nil,
        isOnScreen: Bool = true,
        topLeftX: Double,
        topLeftY: Double,
        fixedWidth: Double? = nil,
        minimumHeight: Double? = nil,
        zoom: Double = 1,
        createdAt: Date = Date()
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
    }
}

struct NoteRecordFile: Codable {
    var version: Int
    var notes: [NoteRecord]
}
