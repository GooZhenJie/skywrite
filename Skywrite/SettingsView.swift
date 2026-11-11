import SkywriteCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: SettingsModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme {
        colorScheme == .dark ? preferences.darkTheme : preferences.lightTheme
    }

    @State private var searchText = ""

    /// The sidebar's own copy of the open pane. Binding the list straight to the shared model made SwiftUI publish model
    /// changes in the middle of a view update ("Publishing changes from within view updates is not allowed"), which the
    /// log showed every time a sidebar row was clicked; the copy is synced to the model after each update instead.
    @State private var selectedPane: SettingsModel.Pane?

    private var visiblePanes: [SettingsModel.Pane] {
        SettingsModel.Pane.allCases.filter { SettingsSearch.matches(searchText, names: $0.searchNames) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPane) {
                if searchText.isEmpty {
                    identity
                }
                ForEach(visiblePanes) { pane in
                    Label {
                        Text(pane.title)
                    } icon: {
                        PaneIcon(pane: pane)
                    }
                    .tag(pane)
                }
                if visiblePanes.isEmpty {
                    Text("No Results")
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                }
            }
            .scrollContentBackground(.hidden)
            .frame(minWidth: SettingsLayout.sidebarWidth)
            .navigationSplitViewColumnWidth(min: SettingsLayout.sidebarWidth, ideal: SettingsLayout.sidebarWidth, max: SettingsLayout.sidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .scrollContentBackground(.hidden)
                // Settings scroll under the toolbar and fade out behind it, like System Settings, instead of running into the title.
                .scrollEdgeEffectStyle(.soft, for: .top)
                .navigationTitle(model.pane.title)
                .toolbar {
                    // The same ‹ › pair System Settings has to the left of the title. macOS also applies its scroll edge
                    // effect underneath toolbar items (WWDC25 session 310), so the settings can fade out behind them.
                    ToolbarItemGroup(placement: .navigation) {
                        Button {
                            model.goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .help("Back")
                        .keyboardShortcut("[", modifiers: .command)
                        .disabled(!model.history.canGoBack)
                        Button {
                            model.goForward()
                        } label: {
                            Label("Forward", systemImage: "chevron.right")
                        }
                        .help("Forward")
                        .keyboardShortcut("]", modifiers: .command)
                        .disabled(!model.history.canGoForward)
                    }
                }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: Text("Search"))
        .onAppear { selectedPane = model.pane }
        .onChange(of: selectedPane) { _, pane in
            if let pane, pane != model.pane {
                model.pane = pane
            }
        }
        .onChange(of: model.pane) { _, pane in
            if selectedPane != pane {
                selectedPane = pane
            }
        }
        .onChange(of: searchText) {
            // A search that hides the open pane clears the list's selection; highlight it again once it's back in the list.
            if selectedPane == nil, visiblePanes.contains(model.pane) {
                selectedPane = model.pane
            }
        }
        .background(theme.background.ignoresSafeArea())
        .tint(theme.accent)
        .alert(String(localized: "Something went wrong"), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0, model.errorMessage != nil { model.errorMessage = nil } })) {
            Button(String(localized: "OK")) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    /// The app icon drawn at the size the sidebar shows it. The icon file has a 32 pt version but no 36 pt one, and
    /// stretching 32 to 36 made the trail look jagged on non-Retina screens; drawing it at the shown size each time
    /// scales down from a larger version instead.
    private static func appIcon(size: CGFloat) -> NSImage {
        let icon = NSApp.applicationIconImage ?? NSImage()
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            icon.draw(in: rect)
            return true
        }
    }

    private var identity: some View {
        HStack(spacing: 10) {
            Image(nsImage: Self.appIcon(size: 36))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Skywrite").font(.headline)
                Text("Notes on your screen").font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .selectionDisabled()
    }

    @ViewBuilder
    private var detail: some View {
        switch model.pane {
        case .general: GeneralSettingsPane()
        case .appearance: AppearanceSettingsPane()
        case .shortcuts: ShortcutsSettingsPane()
        case .storage: StorageSettingsPane()
        case .troubleshooting: TroubleshootingSettingsPane()
        case .uninstall: UninstallSettingsPane()
        case .about: AboutSettingsPane()
        }
    }
}

struct PaneIcon: View {
    let pane: SettingsModel.Pane

    var body: some View {
        glyph
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color(nsColor: pane.tint).gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var glyph: some View {
        if pane.showsAppMark {
            // The menu bar icon is 17 x 15; drawn 15 wide it looked about as wide as the symbols on the other tiles in a test render.
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15 * 15 / 17)
        } else {
            Image(systemName: pane.symbol)
                .font(.system(size: 11, weight: .semibold))
        }
    }
}
