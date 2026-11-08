/// Back and forward through the panes you've looked at, like the ‹ › buttons in System Settings.
public struct NavigationHistory<Item: Equatable> {
    public private(set) var current: Item
    public private(set) var back: [Item] = []
    public private(set) var forward: [Item] = []

    public init(_ current: Item) {
        self.current = current
    }

    public var canGoBack: Bool { !back.isEmpty }
    public var canGoForward: Bool { !forward.isEmpty }

    /// Going somewhere new clears the forward list, the way a browser does.
    public mutating func visit(_ item: Item) {
        guard item != current else { return }
        back.append(current)
        forward.removeAll()
        current = item
    }

    public mutating func goBack() {
        guard let previous = back.popLast() else { return }
        forward.append(current)
        current = previous
    }

    public mutating func goForward() {
        guard let next = forward.popLast() else { return }
        back.append(current)
        current = next
    }
}
