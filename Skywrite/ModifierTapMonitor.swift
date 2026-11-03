import AppKit
import SkywriteCore

final class ModifierTapMonitor {
    private var detector: DoubleTapDetector
    private let onDoubleTap: () -> Void
    private var monitors: [Any] = []

    init(key: TapKey, onDoubleTap: @escaping () -> Void) {
        detector = DoubleTapDetector(key: key, interval: NSEvent.doubleClickInterval)
        self.onDoubleTap = onDoubleTap
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    func restart() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        start()
    }

    private func handle(_ event: NSEvent) {
        detector.interval = NSEvent.doubleClickInterval
        guard event.type == .flagsChanged else {
            detector.interrupt()
            return
        }
        let deviceFlags = event.modifierFlags.rawValue
        guard let isDown = ModifierKey.isDown(keyCode: event.keyCode, deviceFlags: deviceFlags) else {
            detector.interrupt()
            return
        }
        let othersDown = ModifierKey.othersAreDown(besides: event.keyCode, deviceFlags: deviceFlags)
        if detector.modifierChanged(keyCode: event.keyCode, isDown: isDown, otherModifiersDown: othersDown, at: event.timestamp) {
            onDoubleTap()
        }
    }
}
