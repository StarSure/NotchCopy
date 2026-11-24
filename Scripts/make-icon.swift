import AppKit
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for (points, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let pixels = points * scale
    let image = NSImage(size: NSSize(width: CGFloat(pixels), height: CGFloat(pixels)))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200).fill()
    NSColor(calibratedWhite: 0.36, alpha: 1).setStroke()
    let rear = NSBezierPath(roundedRect: NSRect(x: 278, y: 296, width: 404, height: 436), xRadius: 64, yRadius: 64)
    rear.lineWidth = 32
    rear.stroke()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 374, y: 220, width: 404, height: 436), xRadius: 64, yRadius: 64).fill()
    NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 488, y: 612, width: 176, height: 64), xRadius: 24, yRadius: 24).fill()
    for (y, width) in [(CGFloat(488), CGFloat(224)), (CGFloat(408), CGFloat(160))] {
        NSBezierPath(roundedRect: NSRect(x: 460, y: y, width: width, height: 22), xRadius: 11, yRadius: 11).fill()
    }
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let suffix = scale == 2 ? "@2x" : ""
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}
