import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Snap.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let unit = CGFloat(pixels) / 1024
        // Matches the settings window’s app mark. AppKit draws bottom-up, so row != col lights the top-left and bottom-right tiles.
        NSColor(srgbRed: 0xC2 / 255.0, green: 0x54 / 255.0, blue: 0x1D / 255.0, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 50 * unit, y: 50 * unit, width: 924 * unit, height: 924 * unit),
                     xRadius: 210 * unit, yRadius: 210 * unit).fill()
        let inset: CGFloat = 230, gap: CGFloat = 76
        let tile = (924 - 2 * inset - gap) / 2
        for row in 0..<2 {
            for col in 0..<2 {
                NSColor(calibratedWhite: 1, alpha: row != col ? 1 : 0.55).setFill()
                NSBezierPath(roundedRect: NSRect(x: (50 + inset + CGFloat(col) * (tile + gap)) * unit,
                                                 y: (50 + inset + CGFloat(row) * (tile + gap)) * unit,
                                                 width: tile * unit, height: tile * unit),
                             xRadius: 44 * unit, yRadius: 44 * unit).fill()
            }
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not render icon") }
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try png.write(to: directory.appendingPathComponent(name))
    }
}
