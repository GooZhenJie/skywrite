import AppKit
import SwiftUI

/// The search field. An AppKit text field, so Return and the arrow keys reach the list only when an input method isn't
/// using them: Maccy picked an item when Return was meant to confirm a Chinese candidate (p0deje/Maccy#1222).
struct QuickPanelSearchField: NSViewRepresentable {
    @ObservedObject var model: QuickPanelModel

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 18)
        field.placeholderString = String(localized: "Search Notes")
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setAccessibilityIdentifier("quick-panel-search")
        model.searchField = field
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        let isComposing = (field.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
        if !isComposing, field.stringValue != model.query {
            field.stringValue = model.query
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let model: QuickPanelModel

        init(model: QuickPanelModel) {
            self.model = model
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // While an input method is still composing, the field holds letters that aren't the word yet.
            if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() { return }
            model.query = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                model.moveSelection(by: -1)
            case #selector(NSResponder.moveDown(_:)):
                model.moveSelection(by: 1)
            case #selector(NSResponder.insertNewline(_:)):
                model.openSelection()
            case #selector(NSResponder.cancelOperation(_:)):
                model.close()
            default:
                return false
            }
            return true
        }
    }
}
