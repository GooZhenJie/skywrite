import AppKit
import ApplicationServices

final class AccessibilityPermission {
    private var waitingTask: Task<Void, Never>?

    /// Shows the system's request for Accessibility permission, then waits for you to turn Skywrite on in System Settings.
    /// Asking again while already waiting does nothing, so switching between keys doesn't stack up requests.
    func requestIfNeeded(onGranted: @escaping () -> Void) {
        guard !AXIsProcessTrusted(), waitingTask == nil else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        waitingTask = Task { @MainActor [weak self] in
            while !AXIsProcessTrusted() {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
            }
            self?.waitingTask = nil
            onGranted()
        }
    }

    /// Stops waiting, for when pressing twice is turned off before the permission came.
    func stopWaiting() {
        waitingTask?.cancel()
        waitingTask = nil
    }
}

/// Text that names the Accessibility permission the way System Settings does. Simplified Chinese macOS 27 renamed
/// 「隐私与安全性 › 辅助功能」 to 「隐私与安全 › 无障碍」 (Apple's Mac User Guide, "Allow accessibility apps to access your Mac",
/// macOS 26 and 27 versions), so macOS 26 gets its own keys. English and Traditional Chinese read the same in both.
enum AccessibilityPermissionText {
    private static var isMacOS26: Bool {
        !ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    static var waiting: String {
        isMacOS26
            ? String(localized: "Waiting for Accessibility permission (macOS 26)", defaultValue: "Waiting for Accessibility permission")
            : String(localized: "Waiting for Accessibility permission")
    }

    static var whereToTurnOn: String {
        isMacOS26
            ? String(localized: "Turn on Skywrite in Privacy & Security > Accessibility. (macOS 26)",
                     defaultValue: "Turn on Skywrite in Privacy & Security > Accessibility.")
            : String(localized: "Turn on Skywrite in Privacy & Security > Accessibility.")
    }

    static var pressTwiceNeedsPermission: String {
        isMacOS26
            ? String(localized: "Choose a key, then press it twice to make a note. (macOS 26)",
                     defaultValue: "Choose a key, then press it twice to make a note. Skywrite will ask for Accessibility permission so it can notice the key in other apps.")
            : String(localized: "Choose a key, then press it twice to make a note. Skywrite will ask for Accessibility permission so it can notice the key in other apps.")
    }

    static var whereToRemove: String {
        isMacOS26
            ? String(localized: "Accessibility: remove Skywrite in System Settings. (macOS 26)",
                     defaultValue: "Accessibility: remove Skywrite in System Settings › Privacy & Security › Accessibility.")
            : String(localized: "Accessibility: remove Skywrite in System Settings › Privacy & Security › Accessibility.")
    }
}
