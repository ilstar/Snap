import AppKit
import SwiftUI
import SnapCore

@main
enum SnapApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let store = AppStore()
    private let updates = UpdateChecker()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var toast: NSPanel?
    private var toastTimer: Timer?
    private var errorObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Snap", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Snap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem()
        editItem.title = "Edit"
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        let windowItem = NSMenuItem()
        windowItem.title = "Window"
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        errorObserver = NotificationCenter.default.addObserver(forName: .snapError, object: nil, queue: .main) { [weak self] _ in
            self?.showError()
        }
        showSettings()
    }

    /// A template version of the app mark: a rounded square with the 2×2 tiles cut out,
    /// the top-left and bottom-right tiles fully and the other two partly, as in the app icon.
    private static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let body = NSRect(x: 1, y: 1, width: 16, height: 16)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: body, xRadius: 4, yRadius: 4).fill()
            let inset: CGFloat = 3.5, gap: CGFloat = 1.5
            let tile = (body.width - 2 * inset - gap) / 2
            context.setBlendMode(.destinationOut)
            for row in 0..<2 {
                for col in 0..<2 {
                    NSColor(white: 0, alpha: row == col ? 1 : 0.55).setFill()
                    let rect = NSRect(x: body.minX + inset + CGFloat(col) * (tile + gap),
                                      y: body.minY + inset + CGFloat(row) * (tile + gap),
                                      width: tile, height: tile)
                    NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Snap window manager"
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "Snap · Window layouts", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        for preset in store.presets {
            let label = preset.shortcut.map { "   \(ShortcutLabel.text($0))" } ?? ""
            let item = NSMenuItem(title: preset.name + label, action: #selector(applyPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id.uuidString
            item.isEnabled = store.trusted
            menu.addItem(item)
        }
        if store.moving {
            let stop = NSMenuItem(title: "Finish moving", action: #selector(stopMoving), keyEquivalent: "")
            stop.target = self
            menu.addItem(stop)
        }
        if !store.trusted {
            menu.addItem(.separator())
            let enable = NSMenuItem(title: "Enable Accessibility access…", action: #selector(enableAccess), keyEquivalent: "")
            enable.target = self
            menu.addItem(enable)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Layouts & shortcuts…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(withTitle: "Quit Snap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let id = UUID(uuidString: value) else { return }
        // Leave menu tracking before beginning arrow-key capture.
        DispatchQueue.main.async { self.store.run(id) }
    }

    @objc private func stopMoving() { store.stopMoving() }
    @objc private func enableAccess() { store.requestPermission() }
    @objc private func showAbout() { NSApp.orderFrontStandardAboutPanel(nil) }
    @objc private func checkForUpdates() { updates.checkForUpdates() }

    @objc private func showSettings() {
        store.stopMoving()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 820),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "Snap — Layouts & Shortcuts"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .aqua)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.setContentSize(NSSize(width: 980, height: 820))
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        store.stopMoving()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { store.stopMoving() }

    private func showError() {
        guard let message = store.message else { return }
        toastTimer?.invalidate()
        toast?.orderOut(nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 100),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView:
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Snap").font(.system(size: 13, weight: .semibold))
                    Text(message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(18).frame(width: 430, height: 100, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        )
        if let screen = NSScreen.main?.visibleFrame { panel.setFrameOrigin(NSPoint(x: screen.midX - 215, y: screen.maxY - 125)) }
        panel.orderFrontRegardless()
        toast = panel
        toastTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: false) { [weak self] _ in self?.toast?.orderOut(nil) }
    }
}
