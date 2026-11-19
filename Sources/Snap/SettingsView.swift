import SwiftUI
import AppKit
import SnapCore

/// Warm "Sand" palette for the settings window.
enum SandTheme {
    static let background = Color(hex: 0xFBF7F2)
    static let sidebar = Color(hex: 0xF2EADF)
    static let sidebarBorder = Color(hex: 0xE4D8C8)
    static let card = Color.white
    static let cardBorder = Color(hex: 0xECE2D4)
    static let text = Color(hex: 0x231A12)
    static let secondaryText = Color(hex: 0x4A3E33)
    static let mutedText = Color(hex: 0x6B5C4D)
    static let chip = Color(hex: 0xFBF7F2)
    static let keyEdge = Color(hex: 0xDCCDBA)
    static let keyText = Color(hex: 0x2E241B)
    static let iconBackground = Color(hex: 0xFBE8DC)
    static let thumbBorder = Color(hex: 0xD6C7B4)
    static let gridBackground = Color(hex: 0xF5EEE4)
    static let ready = Color(hex: 0x2F8A4E)
    static let accent = Color(hex: 0xC2541D)
    static let link = Color(hex: 0xA9461A)
    static let danger = Color(hex: 0xB42318)
    static let shadow = Color(red: 0.24, green: 0.14, blue: 0.04).opacity(0.07)
}

private typealias Theme = SandTheme

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct CardStyle: ViewModifier {
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.cardBorder))
            .shadow(color: Theme.shadow, radius: 1, y: 1)
    }
}

private extension View {
    func card(radius: CGFloat = 14) -> some View { modifier(CardStyle(radius: radius)) }

    func selectedRowBackground(_ selected: Bool) -> some View {
        background {
            if selected {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white).shadow(color: Theme.shadow, radius: 1, y: 1)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var tab: Tab = .shortcuts
    @State private var filter = ""

    private enum Tab: String, CaseIterable, Identifiable {
        case shortcuts = "Shortcuts", layouts = "Layouts"
        var id: Self { self }
        var symbol: String { self == .shortcuts ? "keyboard" : "rectangle.split.2x2" }
    }

    private var layoutPresets: [Preset] { store.presets.filter { $0.action == .layout } }
    private var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–" }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 224)
            Rectangle().fill(Theme.sidebarBorder).frame(width: 1)
            Group {
                switch tab {
                case .shortcuts: shortcutsPage
                case .layouts: layoutsPage
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
        .environment(\.colorScheme, .light)
        .ignoresSafeArea()
        .frame(minWidth: 900, minHeight: 700)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                AppMark().frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Snap").font(.system(size: 15, weight: .bold))
                    Text("Version \(appVersion)").font(.system(size: 11)).foregroundStyle(Theme.mutedText)
                }
            }.padding(.horizontal, 6)
            VStack(spacing: 2) {
                ForEach(Tab.allCases) { navButton($0) }
            }
            if tab == .layouts { layoutList } else { Spacer(minLength: 0) }
            statusCard
            Text("Snap lives in your menu bar. Closing this window keeps shortcuts running.")
                .font(.system(size: 11)).foregroundStyle(Theme.mutedText).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 6)
        }
        .padding(.horizontal, 12).padding(.top, 48).padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sidebar)
    }

    private func navButton(_ item: Tab) -> some View {
        let selected = tab == item
        return Button { tab = item } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.secondaryText).frame(width: 18)
                Text(item.rawValue).font(.system(size: 13, weight: selected ? .semibold : .medium))
                Spacer()
                if item == .layouts {
                    Text("\(layoutPresets.count)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.mutedText)
                }
            }
            .foregroundStyle(selected ? Theme.text : Theme.secondaryText)
            .padding(.horizontal, 10).frame(height: 34)
            .selectedRowBackground(selected)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).focusEffectDisabled()
    }

    private var layoutList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your layouts").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mutedText)
                .padding(.horizontal, 10)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(layoutPresets) { preset in
                        let selected = store.selectedID == preset.id
                        Button { store.selectedID = preset.id } label: {
                            HStack(spacing: 10) {
                                MiniLayout(selection: preset.selection).frame(width: 26, height: 18)
                                Text(preset.name).font(.system(size: 13, weight: selected ? .semibold : .medium)).lineLimit(1)
                                Spacer(minLength: 4)
                                if let shortcut = preset.shortcut {
                                    Text(ShortcutLabel.text(shortcut)).font(.system(size: 11)).foregroundStyle(Theme.mutedText)
                                }
                            }
                            .padding(.horizontal, 10).frame(height: 34)
                            .selectedRowBackground(selected)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).focusEffectDisabled().accessibilityLabel("\(preset.name), \(ShortcutLabel.text(preset.shortcut))")
                    }
                }
            }
            Button { store.addPreset() } label: {
                Label("New layout", systemImage: "plus").font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).frame(height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.thumbBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Theme.secondaryText).padding(.top, 2)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 8) {
            Circle().fill(store.trusted ? Theme.ready : Theme.accent).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.trusted ? "Accessibility on" : "Setup needed").font(.system(size: 12, weight: .semibold))
                Text(store.trusted ? "Shortcuts are active" : "Grant Accessibility access")
                    .font(.system(size: 11)).foregroundStyle(Theme.mutedText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.sidebarBorder))
    }

    // MARK: Shared pieces

    private func pageTitle(_ headline: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headline).font(.system(size: 24, weight: .bold)).tracking(-0.3)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.mutedText)
        }
    }

    @ViewBuilder private var notices: some View {
        if !store.trusted { permissionBanner }
        if let message = store.message {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.accent)
                Text(message).font(.system(size: 12)).textSelection(.enabled)
                Spacer()
                Button { store.message = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(Theme.mutedText).accessibilityLabel("Dismiss")
            }
            .padding(12)
            .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        if !store.shortcutFailures.isEmpty {
            Text(store.shortcutFailures.joined(separator: "\n")).font(.system(size: 11)).foregroundStyle(Theme.danger)
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill").font(.system(size: 18)).foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36).background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility access needed").font(.system(size: 13, weight: .semibold))
                    Text("macOS has not granted access to this running copy of Snap.")
                        .font(.system(size: 12)).foregroundStyle(Theme.mutedText)
                }
                Spacer()
                Button("Enable access") { store.requestPermission() }.buttonStyle(.borderedProminent)
            }
            DisclosureGroup("Already enabled in System Settings?") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("An older build’s permission may not match this app. Remove the old Snap entry in Accessibility, then add this copy and enable it. Restart Snap if needed.")
                        .font(.system(size: 11)).foregroundStyle(Theme.mutedText).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Show this copy in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        }
                        Button("Check again") { store.refreshPermission() }
                    }.controlSize(.small)
                }.padding(.top, 6)
            }.font(.system(size: 11))
        }
        .padding(14).card()
    }

    @ViewBuilder private func presetIcon(_ preset: Preset) -> some View {
        if preset.action == .layout {
            MiniLayout(selection: preset.selection).frame(width: 34, height: 24)
        } else {
            Image(systemName: preset.action.symbol).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 24)
                .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: Shortcuts

    private var shortcutsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom, spacing: 16) {
                    pageTitle("Shortcuts", "Click any shortcut to record a new one. Use ⌃ or ⌘ plus any other modifiers.")
                    Spacer()
                    filterField
                }
                notices
                HStack(alignment: .top, spacing: 16) {
                    shortcutCard("Layouts", matching { $0.action == .layout }, editLink: true)
                    VStack(spacing: 16) {
                        shortcutCard("Window", matching { [.move, .fullScreen, .restore].contains($0.action) })
                        shortcutCard("Displays", matching { $0.action.movesScreen })
                    }
                }
                generalSettings
            }
            .padding(.horizontal, 32).padding(.top, 36).padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func matching(_ include: (Preset) -> Bool) -> [Preset] {
        store.presets.filter { include($0) && (filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter)) }
    }

    private var filterField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.mutedText)
            TextField("Filter shortcuts", text: $filter).textFieldStyle(.plain).font(.system(size: 13))
            if !filter.isEmpty {
                Button { filter = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(Theme.mutedText).accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 10).frame(width: 210, height: 32)
        .card(radius: 8)
    }

    private func shortcutCard(_ heading: String, _ presets: [Preset], editLink: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(heading).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mutedText)
                Spacer()
                if editLink {
                    Button("Edit layouts") { tab = .layouts }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.link)
                }
            }.padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
            if presets.isEmpty {
                Text("No matching shortcuts").font(.system(size: 12)).foregroundStyle(Theme.mutedText).padding(10)
            }
            ForEach(presets) { shortcutRow($0) }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func shortcutRow(_ preset: Preset) -> some View {
        HStack(spacing: 12) {
            presetIcon(preset)
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name).font(.system(size: 13, weight: .medium)).lineLimit(2)
                if !preset.action.hint.isEmpty {
                    Text(preset.action.hint).font(.system(size: 11)).foregroundStyle(Theme.mutedText).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .help(preset.action.instructions)
            Spacer(minLength: 8)
            ShortcutRecorder(store: store, preset: preset, size: .regular)
        }
        .padding(.horizontal, 10).padding(.vertical, 4).frame(minHeight: 44)
    }

    private var generalSettings: some View {
        HStack(alignment: .top, spacing: 32) {
            sliderSetting("Window spacing", value: $store.gap, range: 0...32, step: 1,
                          note: "Space around snapped windows. Fill screen always uses the whole screen.")
            sliderSetting("Movement step", value: $store.moveStep, range: 4...100, step: 4,
                          note: "How far arrow keys move a window in Move mode. Hold ⇧ for larger steps.")
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func sliderSetting(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(value.wrappedValue)) pt").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.secondaryText)
            }
            Slider(value: value, in: range, step: step).accessibilityLabel(title)
            Text(note).font(.system(size: 11)).foregroundStyle(Theme.mutedText).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }

    // MARK: Layouts

    private var layoutsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let preset = store.selected, preset.action == .layout {
                    editor(preset)
                } else {
                    notices
                }
            }
            .padding(.horizontal, 32).padding(.top, 36).padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if store.selected?.action != .layout { store.selectedID = layoutPresets.first?.id }
        }
    }

    @ViewBuilder private func editor(_ preset: Preset) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Layouts").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.mutedText)
                TextField("Layout name", text: Binding(get: { store.selected?.name ?? "" }, set: { name in
                    guard var current = store.selected else { return }; current.name = name; store.save(current)
                })).font(.system(size: 24, weight: .bold)).textFieldStyle(.plain)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.ready)
                Text("Saved automatically").font(.system(size: 12)).foregroundStyle(Theme.mutedText)
            }
            Button(role: .destructive) { store.deleteSelected() } label: {
                Image(systemName: "trash").font(.system(size: 14)).frame(width: 36, height: 36).card(radius: 8)
            }
            .buttonStyle(.plain).foregroundStyle(Theme.danger).help("Delete layout").accessibilityLabel("Delete layout")
            .disabled(layoutPresets.count <= 1)
        }
        notices
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Drag across the grid to choose the window area.").font(.system(size: 13)).foregroundStyle(Theme.mutedText)
                Spacer()
                Text("Grid").font(.system(size: 12)).foregroundStyle(Theme.mutedText)
                Picker("Columns", selection: selectionBinding(\.columns)) {
                    ForEach(2...12, id: \.self) { Text("\($0) columns").tag($0) }
                }.labelsHidden().frame(width: 116)
                Text("×").foregroundStyle(Theme.mutedText)
                Picker("Rows", selection: selectionBinding(\.rows)) {
                    ForEach(2...12, id: \.self) { Text("\($0) rows").tag($0) }
                }.labelsHidden().frame(width: 92)
            }
            GridEditor(selection: Binding(get: { store.selected?.selection ?? GridSelection() }, set: { selection in
                guard var current = store.selected else { return }; current.selection = selection; store.save(current)
            })).frame(height: 260).id(preset.id)
            HStack(spacing: 8) {
                Text("Quick pick").font(.system(size: 12)).foregroundStyle(Theme.mutedText).padding(.trailing, 2)
                quickButton("Left ½", x: 0, y: 0, width: 3, height: 4)
                quickButton("Right ½", x: 3, y: 0, width: 3, height: 4)
                quickButton("Center ⅔", x: 1, y: 0, width: 4, height: 4)
                quickButton("Fill", x: 0, y: 0, width: 6, height: 4)
                Spacer()
                Text("\(preset.selection.width) × \(preset.selection.height) cells · \(Int(Double(preset.selection.width) / Double(preset.selection.columns) * 100))% × \(Int(Double(preset.selection.height) / Double(preset.selection.rows) * 100))%")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mutedText)
            }
        }
        .padding(16).card(radius: 16)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keyboard shortcut").font(.system(size: 13, weight: .semibold))
                Text("Click to record. Use ⌃ or ⌘ plus any other modifiers.").font(.system(size: 12)).foregroundStyle(Theme.mutedText)
            }
            Spacer()
            ShortcutRecorder(store: store, preset: preset).id(preset.id)
        }
        .padding(.horizontal, 16).padding(.vertical, 14).card(radius: 16)
        HStack {
            Spacer()
            Button("Apply to last window") { store.run(preset.id) }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(!store.trusted)
        }
    }

    private func selectionBinding(_ keyPath: WritableKeyPath<GridSelection, Int>) -> Binding<Int> {
        Binding(get: { store.selected?.selection[keyPath: keyPath] ?? 4 }, set: { value in
            guard var preset = store.selected else { return }; preset.selection[keyPath: keyPath] = value; store.save(preset)
        })
    }

    private func quickButton(_ title: String, x: Int, y: Int, width: Int, height: Int) -> some View {
        let target = GridSelection(x: x, y: y, width: width, height: height)
        let active = store.selected?.selection == target
        return Button {
            guard var preset = store.selected else { return }
            preset.selection = target
            store.save(preset)
        } label: {
            Text(title).font(.system(size: 12, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Theme.accent : Theme.keyText)
                .padding(.horizontal, 12).frame(height: 28)
                .background(active ? Theme.iconBackground : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? Theme.accent : Theme.cardBorder))
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
}

private struct AppMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.accent)
            .overlay {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow { tile(1); tile(0.55) }
                    GridRow { tile(0.55); tile(1) }
                }.padding(7)
            }
            .accessibilityHidden(true)
    }

    private func tile(_ opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(opacity))
    }
}

private struct Keycap: View {
    let text: String
    let large: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: large ? 6 : 5, style: .continuous)
        Text(text).font(.system(size: large ? 14 : 12, weight: .semibold)).foregroundStyle(Theme.keyText)
            .padding(.horizontal, large ? 7 : 5)
            .frame(minWidth: large ? 28 : 22, minHeight: large ? 28 : 22)
            .background(shape.fill(.white).shadow(color: Theme.keyEdge, radius: 0, y: 1))
            .overlay(shape.strokeBorder(Theme.cardBorder))
    }
}

/// Splits a shortcut label such as "⌃⌥←" into one keycap per modifier plus the key.
private func keycaps(_ shortcut: Shortcut) -> [String] {
    let text = ShortcutLabel.text(shortcut)
    let modifierSymbols: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
    let modifiers = text.prefix { modifierSymbols.contains($0) }
    let key = String(text.dropFirst(modifiers.count))
    return modifiers.map(String.init) + (key.isEmpty ? [] : [key])
}

private extension PresetAction {
    var movesScreen: Bool { [.moveScreenLeft, .moveScreenRight, .moveScreenUp, .moveScreenDown].contains(self) }

    var symbol: String {
        switch self {
        case .layout: return "macwindow"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        case .restore: return "arrow.uturn.backward"
        case .moveScreenLeft: return "arrow.left.to.line"
        case .moveScreenRight: return "arrow.right.to.line"
        case .moveScreenUp: return "arrow.up.to.line"
        case .moveScreenDown: return "arrow.down.to.line"
        }
    }

    /// One-line description shown under the shortcut name.
    var hint: String { movesScreen ? "" : headline }

    var headline: String {
        switch self {
        case .layout: return ""
        case .move: return "Make room, one arrow at a time."
        case .fullScreen: return "Give one window the whole screen."
        case .restore: return "Right back where you started."
        case .moveScreenLeft, .moveScreenRight, .moveScreenUp, .moveScreenDown:
            return "Move to another display."
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
        case .moveScreenLeft, .moveScreenRight, .moveScreenUp, .moveScreenDown:
            return "Use the shortcut or menu action to move the focused window in this direction.\nSnap keeps the window’s size when it fits the destination display."
        }
    }
}

struct MiniLayout: View {
    let selection: GridSelection
    var body: some View {
        GeometryReader { geometry in
            let s = selection.normalized
            RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(SandTheme.thumbBorder, lineWidth: 1.5)
            RoundedRectangle(cornerRadius: 2).fill(SandTheme.accent)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SandTheme.gridBackground)
                ForEach(0..<s.rows, id: \.self) { row in
                    ForEach(0..<s.columns, id: \.self) { column in
                        let active = column >= s.x && column < s.x + s.width && row >= s.y && row < s.y + s.height
                        RoundedRectangle(cornerRadius: 4)
                            .fill(active ? SandTheme.accent.opacity(0.14) : Color.white)
                            .frame(width: max(1, w - 7), height: max(1, h - 7))
                            .offset(x: CGFloat(column) * w + 3.5, y: CGFloat(row) * h + 3.5)
                    }
                }
                RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(SandTheme.accent, lineWidth: 2)
                    .frame(width: CGFloat(s.width) * w - 7, height: CGFloat(s.height) * h - 7)
                    .offset(x: CGFloat(s.x) * w + 3.5, y: CGFloat(s.y) * h + 3.5)
                Image(systemName: "macwindow").font(.system(size: 26, weight: .light)).foregroundStyle(SandTheme.accent)
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
    var size: ControlSize = .large
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack(spacing: 6) {
                Button { if recording { finish() } else { start() } } label: { chip }
                    .buttonStyle(.plain)
                    .disabled(store.recording && !recording)
                    .contextMenu {
                        if preset.shortcut != nil { Button("Clear shortcut") { _ = store.assignShortcut(nil, to: preset.id) } }
                    }
                    .help(recording ? "Press a shortcut. Esc cancels, ⌫ clears." : "Click to record. Right-click to clear.")
                    .accessibilityLabel(recording ? "Recording shortcut for \(preset.name)" : "\(preset.name) shortcut: \(ShortcutLabel.text(preset.shortcut))")
                if size == .large && preset.shortcut != nil && !recording {
                    Button { _ = store.assignShortcut(nil, to: preset.id) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(SandTheme.thumbBorder).help("Clear shortcut")
                        .accessibilityLabel("Clear shortcut")
                }
            }
            if let hint { Text(hint).font(.system(size: 10)).foregroundStyle(SandTheme.danger) }
        }
        .onDisappear { finish() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in finish() }
    }

    private var chip: some View {
        let large = size == .large
        let shape = RoundedRectangle(cornerRadius: large ? 9 : 8, style: .continuous)
        return HStack(spacing: large ? 4 : 3) {
            if recording {
                Text("Press keys… Esc cancels").font(.system(size: large ? 13 : 12, weight: .medium))
                    .foregroundStyle(SandTheme.accent).padding(.horizontal, 6)
            } else if let shortcut = preset.shortcut {
                ForEach(Array(keycaps(shortcut).enumerated()), id: \.offset) { Keycap(text: $0.element, large: large) }
            } else {
                Text("Record shortcut").font(.system(size: large ? 13 : 12, weight: .medium))
                    .foregroundStyle(SandTheme.mutedText).padding(.horizontal, 6)
            }
        }
        .frame(minHeight: large ? 28 : 22)
        .padding(large ? 4 : 3)
        .background(recording ? SandTheme.iconBackground : SandTheme.chip, in: shape)
        .overlay(shape.strokeBorder(recording ? SandTheme.accent : SandTheme.cardBorder))
        .contentShape(shape)
    }

    private func start() {
        store.setRecording(true)
        recording = true
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { finish(); return nil }
            if event.keyCode == 51, event.modifierFlags.intersection([.control, .command, .option, .shift]).isEmpty {
                _ = store.assignShortcut(nil, to: preset.id); finish(); return nil
            }
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
