import SwiftUI

/// Skywrite's version and the people to thank: the photographers whose pictures the Appearance pane previews note
/// backgrounds on. The same thanks appear in the About Skywrite window and in the README.
struct AboutSettingsPane: View {
    @EnvironmentObject private var updater: SoftwareUpdater

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "Skywrite").font(.title2.weight(.semibold))
                        Text(Self.version).font(.callout).foregroundStyle(.secondary)
                        Text("Notes on your screen").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Next to the version, as Chrome's About page checks for a newer one (user decision 2026-11-08).
                    CheckForUpdatesButton(updater: updater)
                }
                .padding(.vertical, 6)
            }
            Section {
                Text("The photos you preview note backgrounds on come from these photographers on Unsplash. Thank you!")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ForEach(PreviewBackdrop.allCases) { backdrop in
                    if let page = URL(string: backdrop.credit.page) {
                        LabeledContent {
                            Link(backdrop.credit.photographer, destination: page)
                                .help(backdrop.credit.page)
                        } label: {
                            HStack(spacing: 10) {
                                if let image = backdrop.bundledImage {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 26)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                        .accessibilityHidden(true)
                                }
                                Text(backdrop.title)
                            }
                        }
                    }
                }
            } header: {
                Text("Special Thanks")
            } footer: {
                if let license = URL(string: "https://unsplash.com/license") {
                    Link("Used under the Unsplash License", destination: license)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }
}

extension PreviewBackdrop {
    /// The thanks as a short block of text for the About Skywrite window, each name linking to the photo on Unsplash.
    static func creditsText() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: String(localized: "Special Thanks") + "\n", attributes: base.merging([.font: NSFont.boldSystemFont(ofSize: 12)]) { $1 }))
        text.append(NSAttributedString(string: String(localized: "Preview photos from Unsplash by") + "\n", attributes: base))
        for backdrop in allCases {
            guard let page = URL(string: backdrop.credit.page) else { continue }
            text.append(NSAttributedString(string: backdrop.credit.photographer, attributes: base.merging([.link: page]) { $1 }))
            text.append(NSAttributedString(string: " (\(backdrop.title))\n", attributes: base))
        }
        return text
    }
}
