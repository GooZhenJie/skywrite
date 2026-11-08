import AppKit
import Carbon.HIToolbox

final class GlobalHotkeys {
    private var actions: [UInt32: () -> Void] = [:]
    private var references: [EventHotKeyRef] = []
    private var handlerReference: EventHandlerRef?
    private var nextIdentifier: UInt32 = 1

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let identifier = nextIdentifier
        nextIdentifier += 1
        var reference: EventHotKeyRef?
        let hotKeyIdentifier = EventHotKeyID(signature: OSType(0x534B_5752), id: identifier)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyIdentifier, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else {
            EventLog.input.error("hotkey register failed keyCode=\(keyCode, privacy: .public) modifiers=\(modifiers, privacy: .public) status=\(status, privacy: .public)")
            return
        }
        references.append(reference)
        actions[identifier] = action
    }

    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()
    }

    func fire(_ identifier: UInt32) {
        EventLog.input.notice("hotkey fired id=\(identifier, privacy: .public)")
        actions[identifier]?()
    }

    private func installHandlerIfNeeded() {
        guard handlerReference == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotkeyCallback, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerReference)
    }
}

nonisolated private func hotkeyCallback(_ handler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyIdentifier = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyIdentifier)
    guard status == noErr else { return status }
    let identifier = hotKeyIdentifier.id
    let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        hotkeys.fire(identifier)
    }
    return noErr
}
