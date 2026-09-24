import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift scripts/draw-icon.swift OUTPUT.png")
}

let size = 1024
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 44, y: 44, width: 936, height: 936), xRadius: 215, yRadius: 215)
NSGradient(
    starting: NSColor(calibratedRed: 0.04, green: 0.54, blue: 0.85, alpha: 1),
    ending: NSColor(calibratedRed: 0.035, green: 0.15, blue: 0.39, alpha: 1)
)!.draw(in: tile, angle: -60)

let glow = NSBezierPath(ovalIn: NSRect(x: 100, y: 180, width: 810, height: 810))
NSGradient(
    starting: NSColor(calibratedWhite: 1, alpha: 0.16),
    ending: NSColor(calibratedWhite: 1, alpha: 0)
)!.draw(in: glow, relativeCenterPosition: .zero)

// Leave room for all twelve stars while keeping the drive legible at Finder sizes.
let driveShadow = NSBezierPath(roundedRect: NSRect(x: 353, y: 379, width: 328, height: 250), xRadius: 52, yRadius: 52)
NSColor(calibratedRed: 0.015, green: 0.09, blue: 0.23, alpha: 0.24).setFill()
driveShadow.fill()

let drive = NSBezierPath(roundedRect: NSRect(x: 348, y: 387, width: 328, height: 250), xRadius: 52, yRadius: 52)
NSGradient(
    starting: NSColor.white,
    ending: NSColor(calibratedRed: 0.79, green: 0.9, blue: 0.98, alpha: 1)
)!.draw(in: drive, angle: -90)

let face = NSBezierPath(roundedRect: NSRect(x: 376, y: 468, width: 272, height: 124), xRadius: 25, yRadius: 25)
NSColor(calibratedRed: 0.04, green: 0.30, blue: 0.57, alpha: 1).setFill()
face.fill()

let faceHighlight = NSBezierPath(roundedRect: NSRect(x: 395, y: 544, width: 234, height: 29), xRadius: 14, yRadius: 14)
NSColor(calibratedRed: 0.27, green: 0.65, blue: 0.86, alpha: 0.72).setFill()
faceHighlight.fill()

let slot = NSBezierPath(roundedRect: NSRect(x: 389, y: 424, width: 167, height: 19), xRadius: 9, yRadius: 9)
NSColor(calibratedRed: 0.05, green: 0.31, blue: 0.57, alpha: 1).setFill()
slot.fill()
NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.91, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 602, y: 420, width: 25, height: 25)).fill()

func star(center: NSPoint, outer: CGFloat, inner: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    for point in 0..<10 {
        let angle = CGFloat(point) * CGFloat.pi / 5
        let radius = point.isMultiple(of: 2) ? outer : inner
        let next = NSPoint(x: center.x + sin(angle) * radius, y: center.y + cos(angle) * radius)
        if point == 0 { path.move(to: next) } else { path.line(to: next) }
    }
    path.close()
    color.setFill()
    path.fill()
}

let ringCenter = NSPoint(x: 512, y: 512)
let ringRadius: CGFloat = 338
let gold = NSColor(calibratedRed: 1, green: 0.76, blue: 0.25, alpha: 1)
let dim = NSColor(calibratedRed: 0.57, green: 0.75, blue: 0.86, alpha: 0.60)
for index in 0..<12 {
    let angle = CGFloat(index) * .pi / 6
    let position = NSPoint(
        x: ringCenter.x + sin(angle) * ringRadius,
        y: ringCenter.y + cos(angle) * ringRadius
    )
    star(center: position, outer: 52, inner: 23, color: index < 4 ? gold : dim)
}

NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render MountMate icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
