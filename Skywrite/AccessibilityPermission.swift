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
