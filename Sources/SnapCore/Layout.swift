import Foundation
import CoreGraphics

public struct Shortcut: Codable, Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct GridSelection: Codable, Equatable {
    public var columns: Int
    public var rows: Int
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(columns: Int = 6, rows: Int = 4, x: Int = 0, y: Int = 0, width: Int = 3, height: Int = 4) {
        self.columns = columns
        self.rows = rows
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var normalized: GridSelection {
        let c = min(12, max(2, columns)), r = min(12, max(2, rows))
        let left = min(c - 1, max(0, x)), top = min(r - 1, max(0, y))
        return GridSelection(columns: c, rows: r, x: left, y: top,
                             width: min(c - left, max(1, width)), height: min(r - top, max(1, height)))
    }

    /// Uses Accessibility's top-left coordinate system. Insets never collapse a grid cell.
    public func frame(in screen: CGRect, gap: CGFloat) -> CGRect {
        let s = normalized
        let cellWidth = screen.width / CGFloat(s.columns)
        let cellHeight = screen.height / CGFloat(s.rows)
        let inset = min(max(0, gap), min(cellWidth * CGFloat(s.width), cellHeight * CGFloat(s.height)) / 4)
        return CGRect(x: screen.minX + CGFloat(s.x) * cellWidth + inset,
                      y: screen.minY + CGFloat(s.y) * cellHeight + inset,
                      width: CGFloat(s.width) * cellWidth - inset * 2,
                      height: CGFloat(s.height) * cellHeight - inset * 2)
    }
}

public enum PresetAction: String, Codable {
    case layout, fullScreen, move, restore
}

public struct Preset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var action: PresetAction
    public var selection: GridSelection
    public var shortcut: Shortcut?

    public init(id: UUID = UUID(), name: String, action: PresetAction = .layout,
                selection: GridSelection = GridSelection(), shortcut: Shortcut? = nil) {
        self.id = id
        self.name = name
        self.action = action
        self.selection = selection
        self.shortcut = shortcut
    }

    public static var defaults: [Preset] {
        // Carbon controlKey | optionKey. Hardware key codes allow arrows across keyboard layouts.
        let modifiers: UInt32 = 4096 | 2048
        return [
            Preset(name: "Left half", shortcut: Shortcut(keyCode: 123, modifiers: modifiers)),
            Preset(name: "Right half", selection: GridSelection(x: 3), shortcut: Shortcut(keyCode: 124, modifiers: modifiers)),
            Preset(name: "Top half", selection: GridSelection(width: 6, height: 2), shortcut: Shortcut(keyCode: 126, modifiers: modifiers)),
            Preset(name: "Bottom half", selection: GridSelection(y: 2, width: 6, height: 2), shortcut: Shortcut(keyCode: 125, modifiers: modifiers)),
            Preset(name: "Fill screen", selection: GridSelection(width: 6), shortcut: Shortcut(keyCode: 36, modifiers: modifiers)),
            Preset(name: "Full screen", action: .fullScreen, shortcut: Shortcut(keyCode: 3, modifiers: modifiers)),
            Preset(name: "Move window", action: .move, shortcut: Shortcut(keyCode: 46, modifiers: modifiers)),
            restoreDefault
        ]
    }

    public static var restoreDefault: Preset {
        Preset(name: "Restore window", action: .restore, shortcut: Shortcut(keyCode: 15, modifiers: 4096 | 2048))
    }

    /// Add the new action without changing existing layouts or claiming an occupied shortcut.
    public static func addingRestoreIfMissing(to presets: [Preset]) -> [Preset] {
        guard !presets.contains(where: { $0.action == .restore }) else { return presets }
        var restore = restoreDefault
        if presets.contains(where: { $0.shortcut == restore.shortcut }) { restore.shortcut = nil }
        return presets + [restore]
    }
}

public enum WindowGeometry {
    public static func accessibilityFrame(from appKitFrame: CGRect, mainScreenTop: CGFloat) -> CGRect {
        CGRect(x: appKitFrame.minX, y: mainScreenTop - appKitFrame.maxY,
               width: appKitFrame.width, height: appKitFrame.height)
    }

    public static func moved(_ frame: CGRect, dx: CGFloat, dy: CGFloat, within bounds: CGRect) -> CGRect {
        var result = frame
        result.origin.x = min(max(bounds.minX, frame.minX + dx), max(bounds.minX, bounds.maxX - frame.width))
        result.origin.y = min(max(bounds.minY, frame.minY + dy), max(bounds.minY, bounds.maxY - frame.height))
        return result
    }
}
