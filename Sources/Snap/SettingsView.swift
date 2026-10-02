import SwiftUI
import AppKit
import SnapCore

struct SettingsView: View {
    @ObservedObject var store: AppStore
    private let accent = Color(red: 0.20, green: 0.46, blue: 0.94)

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 238)
            Divider()
            ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A place for every window.").font(.system(size: 25, weight: .semibold))
                        Text("Choose a layout. Make it yours. Keep your hands on the keyboard.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("SNAP").font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(3).foregroundStyle(.secondary)
                }
                if !store.trusted { permissionBanner }
                if let message = store.message {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text(message).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                        Button { store.message = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(12).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                if let preset = store.selected {
                    editor(preset)
                }
                Spacer(minLength: 0)
                Divider()
                Text("GENERAL · ALL LAYOUTS").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Window spacing").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $store.gap, in: 0...32, step: 1).frame(width: 120).accessibilityLabel("Window spacing")
                            Text("\(Int(store.gap)) pt").font(.system(size: 11, design: .monospaced)).frame(width: 42)
                        }
                        Text("Space around snapped windows.\nFill screen always uses the whole screen.")
                            .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Movement step").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $store.moveStep, in: 4...100, step: 4).frame(width: 120).accessibilityLabel("Movement step")
                            Text("\(Int(store.moveStep)) pt").font(.system(size: 11, design: .monospaced)).frame(width: 48)
                        }
                    }
                    Spacer()
                    Label(store.trusted ? "Ready" : "Setup needed", systemImage: store.trusted ? "checkmark.circle.fill" : "lock.circle")
                        .font(.system(size: 11)).foregroundStyle(store.trusted ? .green : .secondary)
                }
            }.padding(28).frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .frame(minWidth: 890, minHeight: 700)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.split.2x2.fill").font(.system(size: 24)).foregroundStyle(accent)
                Text("Snap").font(.system(size: 25, weight: .bold))
            }.padding(.top, 8)
            Text("YOUR LAYOUTS").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.presets) { preset in
                        Button { store.selectedID = preset.id } label: {
                            HStack(spacing: 10) {
                                if preset.action == .layout {
                                    MiniLayout(selection: preset.selection).frame(width: 32, height: 24)
                                } else {
                                    Image(systemName: preset.action.symbol)
                                        .frame(width: 32, height: 24).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    if let shortcut = preset.shortcut {
                                        Text(ShortcutLabel.text(shortcut)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.selectedID == preset.id ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("\(preset.name), \(ShortcutLabel.text(preset.shortcut))")
                    }
                }
            }
            Button { store.addPreset() } label: {
                Label("New layout", systemImage: "plus").frame(maxWidth: .infinity)
            }.controlSize(.large)
            Text("Snap lives in your menu bar.\nClosing this window keeps shortcuts active.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
        }.padding(20).background(.quaternary.opacity(0.3))
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill").font(.system(size: 20)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility access needed").font(.system(size: 13, weight: .semibold))
                    Text("macOS has not granted access to this running copy of Snap.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Enable access") { store.requestPermission() }.buttonStyle(.borderedProminent)
            }
            DisclosureGroup("Already enabled in System Settings?") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("An older build’s permission may not match this app. Remove the old Snap entry in Accessibility, then add this copy and enable it. Restart Snap if needed.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Show this copy in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        }
                        Button("Check again") { store.refreshPermission() }
                    }.controlSize(.small)
                }.padding(.top, 6)
            }.font(.system(size: 11))
        }.padding(14).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private func editor(_ preset: Preset) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                TextField("Layout name", text: Binding(get: { store.selected?.name ?? "" }, set: { name in
                    guard var current = store.selected else { return }; current.name = name; store.save(current)
                })).font(.system(size: 19, weight: .semibold)).textFieldStyle(.plain)
                Spacer()
                if preset.action == .layout {
                    Button(role: .destructive) { store.deleteSelected() } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).help("Delete layout")
                        .disabled(store.presets.filter { $0.action == .layout }.count <= 1)
                }
            }
            if preset.action == .layout {
                HStack {
                    Text("Drag across the grid to choose a window area.").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Columns", selection: selectionBinding(\.columns)) {
                        ForEach(2...12, id: \.self) { Text("\($0)").tag($0) }
                    }.frame(width: 112)
                    Text("×").foregroundStyle(.secondary)
                    Picker("Rows", selection: selectionBinding(\.rows)) {
                        ForEach(2...12, id: \.self) { Text("\($0)").tag($0) }
                    }.frame(width: 94)
                }
                GridEditor(selection: Binding(get: { store.selected?.selection ?? GridSelection() }, set: { selection in
                    guard var current = store.selected else { return }; current.selection = selection; store.save(current)
                })).frame(height: 265).id(preset.id)
                HStack {
                    Text("\(preset.selection.width) × \(preset.selection.height) cells")
                    Spacer()
                    Text("\(Int(Double(preset.selection.width) / Double(preset.selection.columns) * 100))% width · \(Int(Double(preset.selection.height) / Double(preset.selection.rows) * 100))% height")
                }.font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    quickButton("Left ½", x: 0, y: 0, width: 3, height: 4)
                    quickButton("Right ½", x: 3, y: 0, width: 3, height: 4)
                    quickButton("Center ⅔", x: 1, y: 0, width: 4, height: 4)
                    quickButton("Fill", x: 0, y: 0, width: 6, height: 4)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: preset.action.symbol)
                        .font(.system(size: 44, weight: .light)).foregroundStyle(accent)
                    Text(preset.action.headline)
                        .font(.system(size: 18, weight: .medium))
                    Text(preset.action.instructions)
                        .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5)
                }.frame(maxWidth: .infinity).frame(height: 300).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Keyboard shortcut").font(.system(size: 13, weight: .medium))
                    Text("Use Control or Command, plus any other modifiers.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                ShortcutRecorder(store: store, preset: preset).id(preset.id)
            }
            if !store.shortcutFailures.isEmpty {
                Text(store.shortcutFailures.joined(separator: "\n")).font(.system(size: 11)).foregroundStyle(.orange)
            }
            HStack {
                Label("Saved automatically", systemImage: "checkmark").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(preset.action == .restore ? "Restore last window" : preset.action == .move ? "Start movement" : "Apply to last window") { store.run(preset.id) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!store.trusted)
            }
        }
    }

    private func selectionBinding(_ keyPath: WritableKeyPath<GridSelection, Int>) -> Binding<Int> {
        Binding(get: { store.selected?.selection[keyPath: keyPath] ?? 4 }, set: { value in
            guard var preset = store.selected else { return }; preset.selection[keyPath: keyPath] = value; store.save(preset)
        })
    }

    private func quickButton(_ title: String, x: Int, y: Int, width: Int, height: Int) -> some View {
        Button(title) {
            guard var preset = store.selected else { return }
            preset.selection = GridSelection(x: x, y: y, width: width, height: height)
            store.save(preset)
        }.buttonStyle(.bordered).controlSize(.small)
    }
}

private extension PresetAction {
    var symbol: String {
        switch self {
        case .layout: return "macwindow"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        case .restore: return "arrow.uturn.backward"
        }
    }

    var headline: String {
        switch self {
        case .layout: return ""
        case .move: return "Make room, one arrow at a time."
        case .fullScreen: return "Give one window the whole screen."
        case .restore: return "Right back where you started."
        }
    }

    var instructions: String {
        switch self {
        case .layout: return ""
        case .move:
            return "Press your shortcut, then use ↑ ↓ ← →.\nHold Shift for larger steps. Escape or Return finishes.\nSwitching apps or 30 seconds of inactivity also ends movement."
        case .fullScreen:
            return "Enter macOS full screen in its own Space.\nUse the window’s green button or Restore window to exit.\nChoose Fill screen to keep the menu bar and Dock accessible."
        case .restore:
            return "Return to the size and position before your first Snap change.\nEach window remembers its own original frame until restored.\nRestoring also leaves native full screen. History lasts until Snap quits."
        }
    }
}

struct MiniLayout: View {
    let selection: GridSelection
    var body: some View {
        GeometryReader { geometry in
            let s = selection.normalized
            RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.4), lineWidth: 1)
            RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.65))
                .frame(width: max(2, geometry.size.width * CGFloat(s.width) / CGFloat(s.columns) - 4),
                       height: max(2, geometry.size.height * CGFloat(s.height) / CGFloat(s.rows) - 4))
                .offset(x: geometry.size.width * CGFloat(s.x) / CGFloat(s.columns) + 2,
                        y: geometry.size.height * CGFloat(s.y) / CGFloat(s.rows) + 2)
        }
    }
}

struct GridEditor: View {
    @Binding var selection: GridSelection
    @State private var anchor: (Int, Int)?
    var body: some View {
        GeometryReader { geometry in
            let s = selection.normalized
            let w = geometry.size.width / CGFloat(s.columns), h = geometry.size.height / CGFloat(s.rows)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .textBackgroundColor))
                ForEach(0..<s.rows, id: \.self) { row in
                    ForEach(0..<s.columns, id: \.self) { column in
                        let active = column >= s.x && column < s.x + s.width && row >= s.y && row < s.y + s.height
                        RoundedRectangle(cornerRadius: 4)
                            .fill(active ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.055))
                            .frame(width: max(1, w - 7), height: max(1, h - 7))
                            .offset(x: CGFloat(column) * w + 3.5, y: CGFloat(row) * h + 3.5)
                    }
                }
                RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: CGFloat(s.width) * w - 7, height: CGFloat(s.height) * h - 7)
                    .offset(x: CGFloat(s.x) * w + 3.5, y: CGFloat(s.y) * h + 3.5)
                Image(systemName: "macwindow").font(.system(size: 26, weight: .light)).foregroundStyle(Color.accentColor)
                    .position(x: (CGFloat(s.x) + CGFloat(s.width) / 2) * w, y: (CGFloat(s.y) + CGFloat(s.height) / 2) * h)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                func cell(_ point: CGPoint) -> (Int, Int) {
                    (min(s.columns - 1, max(0, Int(point.x / w))), min(s.rows - 1, max(0, Int(point.y / h))))
                }
                let start = anchor ?? cell(value.startLocation)
                anchor = start
                let end = cell(value.location)
                selection = GridSelection(columns: s.columns, rows: s.rows, x: min(start.0, end.0), y: min(start.1, end.1),
                                          width: abs(end.0 - start.0) + 1, height: abs(end.1 - start.1) + 1)
            }.onEnded { _ in anchor = nil })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Window grid")
            .accessibilityValue("\(s.columns) columns, \(s.rows) rows; selection starts at column \(s.x + 1), row \(s.y + 1), spans \(s.width) columns and \(s.height) rows")
        }
        // These controls also let users edit the selection without dragging.
        .contextMenu {
            Button("Expand right") { selection.width += 1; selection = selection.normalized }
            Button("Expand down") { selection.height += 1; selection = selection.normalized }
        }
    }
}

struct ShortcutRecorder: View {
    @ObservedObject var store: AppStore
    let preset: Preset
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack(spacing: 8) {
                Button(recording ? "Press keys… (Esc cancels)" : ShortcutLabel.text(preset.shortcut)) {
                    if recording { finish() } else { start() }
                }.font(.system(size: 12, weight: .medium, design: .monospaced)).controlSize(.large)
                if preset.shortcut != nil && !recording {
                    Button { _ = store.assignShortcut(nil, to: preset.id) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Clear shortcut")
                }
            }
            if let hint { Text(hint).font(.system(size: 10)).foregroundStyle(.orange) }
        }
        .onDisappear { finish() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in finish() }
    }

    private func start() {
        store.setRecording(true)
        recording = true
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { finish(); return nil }
            guard let shortcut = ShortcutLabel.shortcut(from: event) else {
                hint = "Include Control or Command."; return nil
            }
            if store.assignShortcut(shortcut, to: preset.id) { finish() }
            return nil
        }
    }

    private func finish() {
        guard recording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        hint = nil
        store.setRecording(false)
    }
}
