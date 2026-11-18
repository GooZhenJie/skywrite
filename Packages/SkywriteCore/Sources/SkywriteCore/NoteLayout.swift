/// How a note's text is split into cells: how many cells each row has, from top to bottom.
///
/// A plain note is one row with one cell. Every other arrangement (2 × 2, two side by side, two on top and one below)
/// is just another list of numbers, so adding one doesn't touch the code that draws or saves cells; it takes a menu item
/// and an entry in `offered`. Rows with different numbers of cells haven't been tried on screen yet.
public struct NoteLayout: Equatable, Hashable, Sendable {
    public let cellsPerRow: [Int]

    /// Nil when there are no rows or a row has no cells.
    public init?(cellsPerRow: [Int]) {
        guard !cellsPerRow.isEmpty, cellsPerRow.allSatisfy({ $0 > 0 }) else { return nil }
        self.cellsPerRow = cellsPerRow
    }

    private init(validated cellsPerRow: [Int]) {
        self.cellsPerRow = cellsPerRow
    }

    public static let single = NoteLayout(validated: [1])
    public static let twoByTwo = NoteLayout(validated: [2, 2])

    /// The layouts a new note can be made with, and so the only ones a note's file opens with. A file that asks for any
    /// other layout opens as a plain note showing its whole text: Skywrite never writes one,
    /// none has been tried on screen, and a file edited to ask for 100000 cells would otherwise build 100000 text views
    /// at launch. Add a layout here when a menu starts offering it.
    public static let offered: [NoteLayout] = [.single, .twoByTwo]

    public var cellCount: Int {
        cellsPerRow.reduce(0, +)
    }

    /// Anything but a single cell is saved with its layout and shows its cells' first lines as titles.
    public var isGrid: Bool {
        self != .single
    }

    /// The indexes of the cells in each row, in reading order.
    public var rows: [Range<Int>] {
        var start = 0
        return cellsPerRow.map { count in
            defer { start += count }
            return start..<(start + count)
        }
    }

    /// The layout as it's written in a note's file, such as "2, 2".
    public var description: String {
        cellsPerRow.map(String.init).joined(separator: ", ")
    }

    /// Reads what `description` writes. Spaces don't matter; anything that isn't a list of positive whole numbers is nil.
    public init?(description: String) {
        let parts = description.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        self.init(cellsPerRow: numbers)
    }
}
