import AppKit
import ApplicationServices
import SnapCore

enum WindowError: LocalizedError {
    case permission, noWindow, unsupported, failed(AXError), fullScreen, noSavedFrame, restoreFailed
    var errorDescription: String? {
        switch self {
        case .permission: return "Enable Snap in System Settings → Privacy & Security → Accessibility."
        case .noWindow: return "No active window found. Select a window in another app, then try again."
        case .unsupported: return "This window does not support resizing or moving."
        case .failed(let error): return "The app could not update its window (Accessibility error \(error.rawValue))."
        case .fullScreen: return "Leave native full screen before resizing or moving this window."
        case .noSavedFrame: return "No saved position for this window. Resize or move it with Snap first."
        case .restoreFailed: return "This app could not restore the saved window frame. The saved position is still available; try again."
        }
    }
}

final class WindowManager {
    private var lastApplication: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var restoreHistory = WindowRestoreHistory<WindowIdentity>()

    init() {
        lastApplication = NSWorkspace.shared.frontmostApplication
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self?.lastApplication = app
        }
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.restoreHistory.forget { $0.pid == app.processIdentifier }
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        if let terminationObserver { NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver) }
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
        if isFullScreen(window) { throw WindowError.fullScreen }
        for attribute in resize ? [kAXPositionAttribute, kAXSizeAttribute] : [kAXPositionAttribute] {
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(window, attribute as CFString, &settable) == .success,
                  settable.boolValue else { throw WindowError.unsupported }
        }
    }

    private func isFullScreen(_ window: AXUIElement) -> Bool {
        var fullScreen: CFTypeRef?
        return AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreen) == .success
            && (fullScreen as? Bool) == true
    }

    func apply(_ selection: GridSelection, gap: CGFloat) throws {
        let window = try focusedWindow()
        try checkMovable(window, resize: true)
        let original = try frame(of: window)
        let bounds = visibleScreen(for: original)
        let target = selection.frame(in: bounds, gap: gap)
        remember(original, for: window)
        try setFrame(target, of: window)
    }

    private func setFrame(_ target: CGRect, of window: AXUIElement) throws {
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
        guard !isFullScreen(window) else { return }
        remember(try frame(of: window), for: window)
        let error = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanTrue)
        guard error == .success else { throw WindowError.failed(error) }
    }

    func move(_ window: AXUIElement, to position: CGPoint) throws {
        let original = try frame(of: window)
        guard original.origin != position else { return }
        remember(original, for: window)
        try setPosition(position, of: window)
    }

    private func remember(_ frame: CGRect, for window: AXUIElement) {
        let identity = WindowIdentity(window)
        guard restoreHistory.originalFrame(for: identity) == nil else { return }
        // Discard closed windows; AX identity prevents another window from inheriting their history.
        restoreHistory.forget { identity in (try? self.frame(of: identity.element)) == nil }
        restoreHistory.remember(frame, for: identity)
    }

    @MainActor func restore(_ window: AXUIElement) async throws {
        let identity = WindowIdentity(window)
        guard let original = restoreHistory.originalFrame(for: identity) else { throw WindowError.noSavedFrame }
        if isFullScreen(window) {
            let error = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
            guard error == .success else { throw WindowError.failed(error) }
            // Full-screen transitions are asynchronous. Wait without blocking shortcuts or the UI.
            for _ in 0..<50 {
                try Task.checkCancellation()
                if !isFullScreen(window) { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            guard !isFullScreen(window) else { throw WindowError.restoreFailed }
            try await Task.sleep(nanoseconds: 350_000_000)
        }
        try Task.checkCancellation()
        let current = try frame(of: window)
        let needsResize = abs(current.width - original.width) > 3 || abs(current.height - original.height) > 3
        try checkMovable(window, resize: needsResize)
        if needsResize { try setFrame(original, of: window) }
        else { try setPosition(original.origin, of: window) }
        let actual = try frame(of: window)
        guard abs(actual.minX - original.minX) <= 3, abs(actual.minY - original.minY) <= 3 else {
            throw WindowError.restoreFailed
        }
        restoreHistory.forget(identity)
    }

    private func setPosition(_ position: CGPoint, of window: AXUIElement) throws {
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

private struct WindowIdentity: Hashable {
    let element: AXUIElement
    let pid: pid_t

    init(_ element: AXUIElement) {
        self.element = element
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        self.pid = pid
    }

    static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}
