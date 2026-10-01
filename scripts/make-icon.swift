import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Snap.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let unit = CGFloat(pixels) / 1024
        NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.32, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 50 * unit, y: 50 * unit, width: 924 * unit, height: 924 * unit),
                     xRadius: 210 * unit, yRadius: 210 * unit).fill()
        for row in 0..<3 {
            for col in 0..<3 {
                let selected = col < 2 && row > 0
                (selected ? NSColor(calibratedRed: 0.40, green: 0.75, blue: 1, alpha: 1)
                 : NSColor(calibratedWhite: 1, alpha: 0.13)).setFill()
                NSBezierPath(roundedRect: NSRect(x: CGFloat(190 + col * 222) * unit, y: CGFloat(190 + row * 222) * unit,
                                                 width: 200 * unit, height: 200 * unit),
                             xRadius: 32 * unit, yRadius: 32 * unit).fill()
            }
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not render icon") }
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try png.write(to: directory.appendingPathComponent(name))
    }
}
