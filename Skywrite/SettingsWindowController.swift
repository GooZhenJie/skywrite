import AppKit
import Combine
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let preferences: Preferences
    private let onClose: () -> Void
    private var paneSubscription: AnyCancellable?

    init(model: SettingsModel, preferences: Preferences, updater: SoftwareUpdater, onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.onClose = onClose
        let hosting = NSHostingController(rootView: SettingsView().environmentObject(model).environmentObject(preferences).environmentObject(updater))
        // SwiftUI runs the toolbar and title, as in System Settings (itself a SwiftUI app). The title bar is left opaque,
        // as System Settings has it, since macOS draws its scroll edge effect into the title bar area.
        hosting.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: hosting)
        window.title = model.pane.title
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SkywriteSettings")
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        super.init(window: window)
        window.delegate = self
        paneSubscription = model.$pane.sink { [weak window] pane in
            window?.title = pane.title
        }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        EventLog.settings.notice("settings present policy=\(EventLog.activationPolicyName, privacy: .public)")
        NSApp.activateFromFrontmostApp()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        EventLog.settings.notice("settings close")
        onClose()
    }
}

enum SettingsLayout {
    static let windowWidth: CGFloat = 720
    static let windowHeight: CGFloat = 560
    static let sidebarWidth: CGFloat = 220
}
