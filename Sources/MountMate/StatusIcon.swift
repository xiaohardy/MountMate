import AppKit
import MountMateCore

enum StatusIcon {
    /// Renders the twelve slots clockwise from the top of a menu bar-sized icon.
    static func make(state: MountStarSnapshot) -> NSImage {
        let size = NSSize(width: 29, height: 22)
        let image = NSImage(size: size, flipped: false) { _ in
            let center = NSPoint(x: 14.5, y: 11)
            let ringRadius: CGFloat = 8.6
            let ink = NSColor.labelColor
            let dim = ink.withAlphaComponent(0.38)
            let gold = NSColor(calibratedRed: 0.98, green: 0.63, blue: 0.08, alpha: 1)

            for index in 0..<MountStarState.capacity {
                let angle = CGFloat(index) * .pi / 6
                let point = NSPoint(
                    x: center.x + sin(angle) * ringRadius,
                    y: center.y + cos(angle) * ringRadius
                )
                let isLit = state.slots.indices.contains(index) && state.slots[index].isLit
                (isLit ? gold : dim).setFill()
                star(
                    center: point,
                    outer: isLit ? 2.08 : 1.55,
                    inner: isLit ? 1.0 : 0.7
                ).fill()
            }

            let drive = NSBezierPath(
                roundedRect: NSRect(x: 9.1, y: 7.1, width: 10.8, height: 7.8),
                xRadius: 1.55, yRadius: 1.55
            )
            drive.lineWidth = 1.15
            ink.withAlphaComponent(0.88).setStroke()
            drive.stroke()

            let slot = NSBezierPath()
            slot.move(to: NSPoint(x: 11.05, y: 9.25))
            slot.line(to: NSPoint(x: 15.95, y: 9.25))
            slot.lineWidth = 1
            slot.lineCapStyle = .round
            slot.stroke()
            ink.withAlphaComponent(0.88).setFill()
            NSBezierPath(ovalIn: NSRect(x: 17.1, y: 8.55, width: 1.25, height: 1.25)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func star(center: NSPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        for point in 0..<10 {
            let angle = CGFloat(point) * .pi / 5
            let radius = point.isMultiple(of: 2) ? outer : inner
            let next = NSPoint(
                x: center.x + sin(angle) * radius,
                y: center.y + cos(angle) * radius
            )
            if point == 0 { path.move(to: next) }
            else { path.line(to: next) }
        }
        path.close()
        return path
    }
}
