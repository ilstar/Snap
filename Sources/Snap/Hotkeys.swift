import AppKit
import Carbon
import SnapCore

final class HotkeyManager {
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    private var actions: [UInt32: UUID] = [:]
    var onTrigger: ((UUID) -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            if result == noErr, let preset = manager.actions[id.id] { manager.onTrigger?(preset) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func unregister() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()
    }

    func register(_ presets: [Preset]) -> [String] {
        unregister()
        var failures: [String] = []
        var seen = Set<Shortcut>()
        for (index, preset) in presets.enumerated() {
            guard let shortcut = preset.shortcut else { continue }
            guard seen.insert(shortcut).inserted else { failures.append("\(preset.name): duplicate shortcut"); continue }
            let id = UInt32(index + 1)
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                            EventHotKeyID(signature: 0x534E4150, id: id),
                                            GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference {
                references.append(reference)
                actions[id] = preset.id
            } else { failures.append("\(preset.name): shortcut is unavailable (\(result))") }
        }
        return failures
    }

    deinit {
        unregister()
        if let handler { RemoveEventHandler(handler) }
    }
}

enum ShortcutLabel {
    static func text(_ shortcut: Shortcut?) -> String {
        guard let shortcut else { return "Record shortcut" }
        var text = ""
        if shortcut.modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if shortcut.modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if shortcut.modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        let special: [UInt32: String] = [123: "←", 124: "→", 125: "↓", 126: "↑", 36: "↩", 49: "Space", 48: "⇥", 51: "⌫"]
        if let label = special[shortcut.keyCode] { return text + label }
        // Translate hardware key codes using the current keyboard layout.
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
            let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKey: UInt32 = 0, count = 0
            var characters = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, UInt16(shortcut.keyCode), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKey, characters.count, &count, &characters)
            if status == noErr, count > 0 { return text + String(utf16CodeUnits: characters, count: count).uppercased() }
        }
        return text + "Key \(shortcut.keyCode)"
    }

    static func shortcut(from event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require Control or Command to keep normal typing available system-wide.
        guard flags.contains(.control) || flags.contains(.command) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }
}
