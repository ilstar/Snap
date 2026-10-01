import AppKit
import Combine
import SnapCore

final class AppStore: ObservableObject {
    @Published private(set) var presets: [Preset]
    @Published var selectedID: UUID?
    @Published private(set) var trusted = false
    @Published private(set) var moving = false
    @Published var message: String?
    @Published var shortcutFailures: [String] = []
    @Published var gap: Double { didSet { UserDefaults.standard.set(gap, forKey: "windowGap") } }
    @Published var moveStep: Double { didSet { UserDefaults.standard.set(moveStep, forKey: "moveStep") } }
    private let windows = WindowManager()
    private let hotkeys = HotkeyManager()
    private lazy var movement = MovementMode(windows: windows)
    private var permissionTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var recording = false

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "presets"), let decoded = try? JSONDecoder().decode([Preset].self, from: data),
           !decoded.isEmpty, Set(decoded.map(\.id)).count == decoded.count {
            presets = decoded.map { var preset = $0; preset.selection = preset.selection.normalized; return preset }
        } else { presets = Preset.defaults }
        gap = defaults.object(forKey: "windowGap") == nil ? 8 : min(32, max(0, defaults.double(forKey: "windowGap")))
        moveStep = defaults.object(forKey: "moveStep") == nil ? 24 : min(100, max(4, defaults.double(forKey: "moveStep")))
        selectedID = presets.first?.id
        hotkeys.onTrigger = { [weak self] id in self?.run(id) }
        movement.onEnd = { [weak self] in self?.moving = false }
        movement.onError = { [weak self] message in self?.report(message) }
        trusted = windows.trusted
        registerHotkeys()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshPermission() }
    }

    var selected: Preset? { presets.first { $0.id == selectedID } }

    func save(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        var updated = preset
        updated.selection = updated.selection.normalized
        presets[index] = updated
        persist()
    }

    func addPreset() {
        let preset = Preset(name: "Custom layout")
        presets.append(preset)
        selectedID = preset.id
        persist()
    }

    func deleteSelected() {
        guard let selected, selected.action == .layout, presets.filter({ $0.action == .layout }).count > 1 else { return }
        presets.removeAll { $0.id == selected.id }
        selectedID = presets.first?.id
        persist()
    }

    func assignShortcut(_ shortcut: Shortcut?, to id: UUID) -> Bool {
        if let shortcut, let conflict = presets.first(where: { $0.id != id && $0.shortcut == shortcut }) {
            message = "This shortcut is already assigned to \(conflict.name)."
            return false
        }
        guard var preset = presets.first(where: { $0.id == id }) else { return false }
        preset.shortcut = shortcut
        save(preset)
        message = nil
        return true
    }

    func setRecording(_ recording: Bool) {
        self.recording = recording
        if recording { movement.stop(); hotkeys.unregister() } else { registerHotkeys() }
    }

    func run(_ id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }), !recording else { return }
        let wasMoving = moving
        movement.stop()
        message = nil
        do {
            switch preset.action {
            case .layout: try windows.apply(preset.selection, gap: gap)
            case .fullScreen: try windows.enterFullScreen()
            case .move:
                if wasMoving { return }
                movement.step = moveStep
                movement.activationShortcut = preset.shortcut
                try movement.start()
                moving = true
            }
        } catch { report(error.localizedDescription) }
    }

    func requestPermission() { windows.requestPermission() }
    func refreshPermission() {
        let current = windows.trusted
        if trusted != current { trusted = current }
        if !current { movement.stop() }
        if current, message == WindowError.permission.localizedDescription { message = nil }
    }
    func stopMoving() { movement.stop() }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) { UserDefaults.standard.set(data, forKey: "presets") }
        if !recording { registerHotkeys() }
    }

    private func registerHotkeys() { shortcutFailures = hotkeys.register(presets) }

    private func report(_ text: String) {
        message = text
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue
        ])
        NSSound.beep()
        NotificationCenter.default.post(name: .snapError, object: nil)
    }

    deinit {
        permissionTimer?.invalidate()
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }
}

extension Notification.Name {
    static let snapError = Notification.Name("SnapError")
}
