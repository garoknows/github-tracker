import AppKit
import SwiftUI

/// Draws the menu bar icon: the Primary profile's last 7 days as a strip, or a plain 3×3 glyph.
public enum MenuBarIcon {
    public static func image(style: MenuBarIconStyle, snapshot: ProfileSnapshot?, theme: ColorTheme,
                             dark: Bool, today: CivilDate = CivilDate(Date())) -> NSImage {
        guard style == .strip, let snapshot else { return glyph() }
        let days = snapshot.calendar.days.filter { $0.date <= today }.suffix(7)
        let colors = theme.levels(dark ? .dark : .light)
        let cell: CGFloat = 4, gap: CGFloat = 1.5
        let size = NSSize(width: 7 * cell + 6 * gap, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            for (i, day) in days.enumerated() {
                let rect = NSRect(x: CGFloat(i) * (cell + gap), y: (size.height - cell * 2.5) / 2, width: cell, height: cell * 2.5)
                let color = day.count == 0 ? NSColor.gray.withAlphaComponent(0.35) : NSColor(colors[day.level])
                color.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Last 7 days for @\(snapshot.login): \(days.map(\.count).reduce(0, +)) contributions"
        return image
    }

    /// Monochrome template image so macOS tints it for light and dark menu bars.
    public static func glyph() -> NSImage {
        let opacities: [CGFloat] = [0.35, 1, 0.6, 1, 0.35, 1, 0.6, 1, 0.35]
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            for (i, a) in opacities.enumerated() {
                NSColor.black.withAlphaComponent(a).setFill()
                let rect = NSRect(x: 1 + CGFloat(i % 3) * 5, y: 1 + CGFloat(i / 3) * 5, width: 4, height: 4)
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tracker for GitHub"
        return image
    }
}
