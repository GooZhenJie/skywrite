import AppKit
import ApplicationServices

final class AccessibilityPermission {
    private var waitingTask: Task<Void, Never>?

    func requestIfNeeded(onGranted: @escaping () -> Void) {
        guard !AXIsProcessTrusted() else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        waitingTask = Task { @MainActor in
            while !AXIsProcessTrusted() {
                try? await Task.sleep(for: .seconds(2))
            }
            onGranted()
        }
    }
}
