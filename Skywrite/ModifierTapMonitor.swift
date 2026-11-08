import AppKit
import SkywriteCore

final class ModifierTapMonitor {
    private var detector: DoubleTapDetector
    private let onDoubleTap: () -> Void
    private var monitors: [Any] = []
    private var menuTrackingTap: CFMachPort?
    private var menuTrackingSource: CFRunLoopSource?
    /// UI tests widen the double-tap window, because each synthesized key press takes a while.
    var intervalOverride: TimeInterval?

    init(key: TapKey, onDoubleTap: @escaping () -> Void) {
        detector = DoubleTapDetector(key: key, interval: NSEvent.doubleClickInterval)
        self.onDoubleTap = onDoubleTap
    }

    func start() {
        EventLog.input.notice("tap monitor start")
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
        stop()
        start()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        stopWatchingDuringMenuTracking()
    }

    /// Keeps catching the tap key while one of Skywrite's own menus is open.
    ///
    /// Menu tracking consumes key events before either NSEvent monitor sees them: the global one only gets events
    /// sent to other apps, and Apple's `addLocalMonitorForEvents` documentation says it isn't called for events
    /// consumed by menu tracking. A Carbon handler on the app's event target got nothing either (tried 2026-11-06).
    /// A listen-only event tap sees modifier changes before any app or menu does, so one runs while the menu is open.
    /// If macOS won't create it (missing permission), the menu simply doesn't react to the tap, as before.
    func startWatchingDuringMenuTracking() {
        guard menuTrackingTap == nil else { return }
        let flagsChanged = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: flagsChanged, callback: { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<ModifierTapMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.menuTrackingTapReceived(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            EventLog.input.notice("menu tracking event tap could not be created")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        menuTrackingTap = tap
        menuTrackingSource = source
        EventLog.input.notice("menu tracking event tap start")
    }

    func stopWatchingDuringMenuTracking() {
        guard let menuTrackingTap else { return }
        CGEvent.tapEnable(tap: menuTrackingTap, enable: false)
        if let menuTrackingSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), menuTrackingSource, .commonModes)
        }
        CFMachPortInvalidate(menuTrackingTap)
        self.menuTrackingTap = nil
        menuTrackingSource = nil
    }

    private func menuTrackingTapReceived(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let menuTrackingTap {
                CGEvent.tapEnable(tap: menuTrackingTap, enable: true)
            }
        case .flagsChanged:
            if let modifierEvent = NSEvent(cgEvent: event) {
                handleDuringMenuTracking(modifierEvent)
            }
        default:
            break
        }
    }

    private func handleDuringMenuTracking(_ event: NSEvent) {
        let keyCode = event.type == .flagsChanged ? String(event.keyCode) : "none"
        EventLog.input.notice("modifier change while a menu is open type=\(event.type.rawValue, privacy: .public) keyCode=\(keyCode, privacy: .public)")
        handle(event)
    }

    private func handle(_ event: NSEvent) {
        detector.interval = intervalOverride ?? NSEvent.doubleClickInterval
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
            EventLog.input.notice("double tap detected keyCode=\(event.keyCode, privacy: .public) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown", privacy: .public)")
            onDoubleTap()
        }
    }
}
