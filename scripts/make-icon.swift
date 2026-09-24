import AppKit
import Foundation
let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let n = CGFloat(pixels)
        let base = NSBezierPath(roundedRect: NSRect(x: n*0.06, y: n*0.06, width: n*0.88, height: n*0.88), xRadius: n*0.2, yRadius: n*0.2)
        NSGradient(starting: NSColor(calibratedRed: 0.19, green: 0.53, blue: 0.94, alpha: 1), ending: NSColor(calibratedRed: 0.15, green: 0.28, blue: 0.74, alpha: 1))!.draw(in: base, angle: -70)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: n*0.25, y: n*0.23, width: n*0.5, height: n*0.55), xRadius: n*0.05, yRadius: n*0.05).fill()
        NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.85, alpha: 1).setFill()
        for y in [0.57, 0.45, 0.33] {
            NSBezierPath(roundedRect: NSRect(x: n*0.33, y: n*y, width: n*(y == 0.45 ? 0.26 : 0.34), height: n*0.045), xRadius: n*0.02, yRadius: n*0.02).fill()
        }
        image.unlockFocus()
        let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: URL(fileURLWithPath: "\(folder)/icon_\(size)x\(size)\(suffix).png"))
    }
}
