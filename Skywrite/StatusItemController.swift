import AppKit

final class StatusItemController {
    private var statusItem: NSStatusItem?
    private var visibilityObservation: NSKeyValueObservation?
    private let menu: NSMenu
    private let onRemovedByUser: () -> Void

    init(menu: NSMenu, onRemovedByUser: @escaping () -> Void) {
        self.menu = menu
        self.onRemovedByUser = onRemovedByUser
    }

    func setVisible(_ visible: Bool) {
        if visible {
            add()
        } else {
            remove()
        }
    }

    private func add() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = .removalAllowed
        item.button?.image = NSImage(named: "MenuBarIcon")
        item.button?.setAccessibilityLabel("Skywrite")
        item.button?.setAccessibilityIdentifier("skywrite-status-item")
        item.menu = menu
        visibilityObservation = item.observe(\.isVisible, options: [.old, .new]) { [weak self] _, change in
            guard change.oldValue == true, change.newValue == false else { return }
            MainActor.assumeIsolated {
                self?.onRemovedByUser()
            }
        }
        statusItem = item
    }

    private func remove() {
        visibilityObservation = nil
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }
}
