import AppKit
import ApplicationServices
import SnapCore

enum WindowError: LocalizedError {
    case permission, noWindow, unsupported, failed(AXError), fullScreen
    var errorDescription: String? {
        switch self {
        case .permission: return "Enable Snap in System Settings → Privacy & Security → Accessibility."
        case .noWindow: return "No active window found. Select a window in another app, then try again."
        case .unsupported: return "This window does not support resizing or moving."
        case .failed(let error): return "The app could not update its window (Accessibility error \(error.rawValue))."
        case .fullScreen: return "Leave native full screen before resizing or moving this window."
        }
    }
}

final class WindowManager {
    private var lastApplication: NSRunningApplication?
    private var observer: NSObjectProtocol?

    init() {
        lastApplication = NSWorkspace.shared.frontmostApplication
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self?.lastApplication = app
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    var trusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func focusedWindow() throws -> AXUIElement {
        guard trusted else { throw WindowError.permission }
        let front = NSWorkspace.shared.frontmostApplication
        let app = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? lastApplication : front
        guard let app, !app.isTerminated else { throw WindowError.noWindow }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.3)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { throw WindowError.noWindow }
        return value as! AXUIElement
    }

    func frame(of window: AXUIElement) throws -> CGRect {
        var point = CGPoint.zero, size = CGSize.zero
        var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { throw WindowError.unsupported }
        return CGRect(origin: point, size: size)
    }

    func visibleScreen(for frame: CGRect) -> CGRect {
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { WindowGeometry.accessibilityFrame(from: $0.visibleFrame, mainScreenTop: mainTop) }
        return screens.max { a, b in
            let aa = a.intersection(frame), bb = b.intersection(frame)
            return (aa.isNull ? 0 : aa.width * aa.height) < (bb.isNull ? 0 : bb.width * bb.height)
        } ?? frame
    }

    func checkMovable(_ window: AXUIElement, resize: Bool = false) throws {
        var fullScreen: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreen) == .success,
           (fullScreen as? Bool) == true { throw WindowError.fullScreen }
        for attribute in resize ? [kAXPositionAttribute, kAXSizeAttribute] : [kAXPositionAttribute] {
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(window, attribute as CFString, &settable) == .success,
                  settable.boolValue else { throw WindowError.unsupported }
        }
    }

    func apply(_ selection: GridSelection, gap: CGFloat) throws {
        let window = try focusedWindow()
        try checkMovable(window, resize: true)
        let bounds = visibleScreen(for: try frame(of: window))
        let target = selection.frame(in: bounds, gap: gap)
        // Resize first so large windows can be moved into a smaller target region.
        try setSize(target.size, of: window)
        try setPosition(target.origin, of: window)
        try setSize(target.size, of: window)
        let actual = try frame(of: window)
        if abs(actual.width - target.width) > 3 || abs(actual.height - target.height) > 3 {
            throw WindowError.unsupported
        }
    }

    func enterFullScreen() throws {
        let window = try focusedWindow()
        let error = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanTrue)
        guard error == .success else { throw WindowError.failed(error) }
    }

    func setPosition(_ position: CGPoint, of window: AXUIElement) throws {
        var value = position
        guard let axValue = AXValueCreate(.cgPoint, &value) else { throw WindowError.unsupported }
        let error = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue)
        guard error == .success else { throw WindowError.failed(error) }
    }

    private func setSize(_ size: CGSize, of window: AXUIElement) throws {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { throw WindowError.unsupported }
        let error = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue)
        guard error == .success else { throw WindowError.failed(error) }
    }
}
