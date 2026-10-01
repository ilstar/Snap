import AppKit
import ApplicationServices
import SwiftUI
import SnapCore

final class MovementMode {
    private let windows: WindowManager
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var window: AXUIElement?
    private var hud: NSPanel?
    private var timeout: Timer?
    private var activationObserver: NSObjectProtocol?
    var step: CGFloat = 24
    var activationShortcut: Shortcut?
    var onEnd: (() -> Void)?
    var onError: ((String) -> Void)?

    init(windows: WindowManager) {
        self.windows = windows
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stop() }
    }

    func start() throws {
        stop()
        let target = try windows.focusedWindow()
        try windows.checkMovable(target)
        let frame = try windows.frame(of: target)
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                             options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let mode = Unmanaged<MovementMode>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async { mode.stop() }
                return Unmanaged.passUnretained(event)
            }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let modifiers = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
            let arrow = (123...126).contains(code)
            let finish = code == 53 || code == 36
            if let activationShortcut = mode.activationShortcut, let nsEvent = NSEvent(cgEvent: event),
               ShortcutLabel.shortcut(from: nsEvent) == activationShortcut {
                return Unmanaged.passUnretained(event)
            }
            if !modifiers.isEmpty || (!arrow && !finish) {
                if type == .keyDown { DispatchQueue.main.async { mode.stop() } }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown {
                let fast = event.flags.contains(.maskShift)
                DispatchQueue.main.async {
                    if finish { mode.stop() } else { mode.move(keyCode: code, fast: fast) }
                }
            }
            return nil
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw MovementError.keyboardAccess
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            throw MovementError.keyboardAccess
        }
        window = target
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        showHUD(for: frame)
        resetTimeout()
    }

    func stop() {
        let wasActive = window != nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        window = nil
        timeout?.invalidate()
        timeout = nil
        hud?.orderOut(nil)
        hud = nil
        if wasActive { onEnd?() }
    }

    private func move(keyCode: Int64, fast: Bool) {
        guard let window else { return }
        do {
            let frame = try windows.frame(of: window)
            let amount = step * (fast ? 4 : 1)
            let dx: CGFloat = keyCode == 123 ? -amount : keyCode == 124 ? amount : 0
            let dy: CGFloat = keyCode == 126 ? -amount : keyCode == 125 ? amount : 0
            let moved = WindowGeometry.moved(frame, dx: dx, dy: dy, within: windows.visibleScreen(for: frame))
            try windows.move(window, to: moved.origin)
            resetTimeout()
        } catch { stop(); onError?(error.localizedDescription) }
    }

    private func resetTimeout() {
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in self?.stop() }
    }

    private func showHUD(for frame: CGRect) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 450, height: 64),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView:
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Move window with arrow keys").font(.system(size: 13, weight: .semibold))
                    Text("Shift for larger steps · Esc or Return to finish").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("↑ ↓ ← →").font(.system(size: 17, weight: .medium, design: .monospaced))
            }.padding(16).frame(width: 450, height: 64).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
        let bounds = windows.visibleScreen(for: frame)
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        panel.setFrameOrigin(NSPoint(x: bounds.midX - 225, y: mainTop - bounds.maxY + 28))
        panel.orderFrontRegardless()
        hud = panel
    }

    deinit {
        stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }
}

enum MovementError: LocalizedError {
    case keyboardAccess
    var errorDescription: String? {
        "Snap could not start keyboard control. Enable Accessibility access, then restart Snap. If macOS requests Input Monitoring, enable Snap there too."
    }
}
