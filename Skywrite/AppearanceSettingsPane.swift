import AppKit
import SkywriteCore
import SwiftUI

struct AppearanceSettingsPane: View {
    @EnvironmentObject private var preferences: Preferences

    private var backdrop: PreviewBackdrop {
        preferences.previewBackdrop
    }

    var body: some View {
        Form {
            Section("Theme") {
                ThemeRow(title: String(localized: "In Dark Mode"), themes: Theme.dark, selection: $preferences.darkTheme)
                ThemeRow(title: String(localized: "In Light Mode"), themes: Theme.light, selection: $preferences.lightTheme)
            }
            Section("Note Background") {
                HStack(spacing: 14) {
                    ForEach(GlassStyle.allCases, id: \.self) { style in
                        GlassOption(style: style, isSelected: preferences.glassStyle == style, strength: preferences.glassStrength, wallpaper: backdrop.bundledImage) {
                            preferences.glassStyle = style
                        }
                    }
                }
                .padding(.vertical, 4)
                LabeledContent("Preview on") {
                    HStack(spacing: 8) {
                        ForEach(PreviewBackdrop.allCases) { choice in
                            BackdropSwatch(backdrop: choice, isSelected: backdrop == choice) {
                                preferences.previewBackdrop = choice
                            }
                        }
                    }
                }
                if preferences.glassStyle == .softEdge {
                    LabeledContent("Strength") {
                        HStack {
                            Text("None").font(.callout).foregroundStyle(.secondary)
                            Slider(value: $preferences.glassStrength, in: 0...1)
                                .frame(maxWidth: 220)
                                .accessibilityLabel("Strength")
                            Text("More").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Toggle(isOn: $preferences.liquidGlassStaysClear) {
                        Text("Stay clear when you’re not using the note")
                        Text("macOS normally dims glass in windows you aren’t using.").font(.callout)
                    }
                    .accessibilityIdentifier("liquid-glass-stays-clear")
                    Text("Follows Liquid Glass in System Settings › Appearance.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Text") {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(verbatim: "A").font(.system(size: 12)).accessibilityHidden(true)
                        Slider(value: $preferences.fontSize, in: NoteMetrics.minimumFontSize...NoteMetrics.maximumFontSize, step: NoteMetrics.fontSizeStep)
                            .frame(maxWidth: 220)
                            .accessibilityLabel("Text size")
                            .accessibilityValue("\(Int(preferences.fontSize)) pt")
                        Text(verbatim: "A").font(.system(size: 20)).accessibilityHidden(true)
                        Text("\(Int(preferences.fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                } label: {
                    Text("Text size")
                    Text("⌘+ / ⌘− changes this for every note").font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ThemeRow: View {
    let title: String
    let themes: [Theme]
    @Binding var selection: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
            HStack(spacing: 12) {
                ForEach(themes) { theme in
                    Button {
                        selection = theme
                    } label: {
                        VStack(spacing: 5) {
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.background)
                                Capsule().fill((theme.isDark ? Color.white : Color.black).opacity(0.45))
                                    .frame(width: 30, height: 4)
                                    .offset(x: 8, y: 9)
                                Capsule().fill(theme.accent)
                                    .frame(width: 22, height: 7)
                                    .offset(x: 8, y: 24)
                            }
                            .frame(width: 64, height: 40)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(selection == theme ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selection == theme ? 3 : 0.5)
                            }
                            Text(theme.name)
                                .font(.callout)
                                .fontWeight(selection == theme ? .semibold : .regular)
                                .foregroundStyle(selection == theme ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.name)
                    .accessibilityAddTraits(selection == theme ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension GlassStyle {
    var title: String {
        switch self {
        case .softEdge: String(localized: "Soft Edge")
        case .liquidGlass: String(localized: "Liquid Glass")
        }
    }
}

/// What the note background cards sit on: one of the photos bundled with Skywrite, so you can see how each background
/// looks over light, dark and busy pictures before choosing.
///
/// There used to be a "Your desktop picture" choice. It was removed on 2026-11-08: for the wallpapers macOS draws itself,
/// NSWorkspace.desktopImageURL(for:) reports the system's default picture (/System/Library/CoreServices/DefaultDesktop.heic)
/// rather than what's on screen, so the preview showed a picture that wasn't yours.
///
/// The bundled photos come from Unsplash under the Unsplash License (https://unsplash.com/license, read 2026-11-07):
/// free to use, change and ship in an app, no credit required. Skywrite thanks the photographers anyway, by name, in
/// each swatch's tooltip, on the About pane, in the About Skywrite window, in the README and in each photo's metadata.
///
/// The sea photo comes first and is where the previews start (user decision 2026-11-08).
///
/// Special thanks to Ishan @seefromthesky (sea), Francesco Ungaro (canyon, dunes), Arindam Saha (mountains) and
/// Nathan Dumlao (city).
enum PreviewBackdrop: String, CaseIterable, Identifiable {
    case sea
    case canyon
    case dunes
    case mountains
    case city

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sea: String(localized: "Sea")
        case .canyon: String(localized: "Canyon")
        case .dunes: String(localized: "Dunes")
        case .mountains: String(localized: "Mountains")
        case .city: String(localized: "City")
        }
    }

    /// The photographer and the photo's page on Unsplash.
    var credit: (photographer: String, page: String) {
        switch self {
        case .sea: ("Ishan @seefromthesky", "https://unsplash.com/photos/BMJWpck6eQA")
        case .canyon: ("Francesco Ungaro", "https://unsplash.com/photos/ZDriZvoHeKk")
        case .dunes: ("Francesco Ungaro", "https://unsplash.com/photos/p3NOK6MhvKQ")
        case .mountains: ("Arindam Saha", "https://unsplash.com/photos/PwzISwC2kLs")
        case .city: ("Nathan Dumlao", "https://unsplash.com/photos/SwIh3kr1__U")
        }
    }

    var help: String {
        String(localized: "\(title) — photo by \(credit.photographer) on Unsplash")
    }

    var bundledImage: NSImage? {
        switch self {
        case .sea: NSImage(named: "PreviewSea")
        case .canyon: NSImage(named: "PreviewCanyon")
        case .dunes: NSImage(named: "PreviewDunes")
        case .mountains: NSImage(named: "PreviewMountains")
        case .city: NSImage(named: "PreviewCity")
        }
    }
}

struct BackdropSwatch: View {
    let backdrop: PreviewBackdrop
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Group {
                if let image = backdrop.bundledImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 40, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .help(backdrop.help)
        .accessibilityLabel(backdrop.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct GlassOption: View {
    let style: GlassStyle
    let isSelected: Bool
    let strength: Double
    let wallpaper: NSImage?
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 7) {
                ZStack {
                    backdrop
                    Text("Buy milk")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background { glass }
                }
                .frame(width: 150, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 3 : 0.5)
                }
                Text(style.title)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Every card uses the same picture with the same crop, so only the glass differs between them.
    @ViewBuilder
    private var backdrop: some View {
        if let wallpaper {
            Image(nsImage: wallpaper)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 92)
                .clipped()
        } else {
            Color(white: 0.3)
        }
    }

    @ViewBuilder
    private var glass: some View {
        switch style {
        case .softEdge:
            Rectangle().fill(.ultraThinMaterial).opacity(strength).blur(radius: 4)
        case .liquidGlass:
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 8, style: .continuous))
        }
    }
}
