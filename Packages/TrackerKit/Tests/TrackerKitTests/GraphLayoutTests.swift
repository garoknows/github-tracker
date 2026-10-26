import AppKit
import SwiftUI
import Testing
@testable import TrackerKit

/// Regression tests for the 1.0.0 bug: the year graph collapsed to zero height inside the menu bar
/// popover, because it was fully flexible and the popover measured its content with no room for it.
@MainActor
@Suite("Graph layout", .serialized)
struct GraphLayoutTests {
    func graphSize(_ view: some View, proposing size: CGSize) -> CGSize {
        NSHostingController(rootView: view).sizeThatFits(in: size)
    }

    @Test(arguments: [CGFloat(0), 1, 10_000, .greatestFiniteMagnitude])
    func graphKeepsItsHeightWhateverHeightIsOffered(height: CGFloat) throws {
        let days = try ScreenshotTests.garo().calendar.days
        let size = graphSize(ContributionGraphView(days: days, theme: .green), proposing: CGSize(width: 488, height: height))
        // 53 weeks with labels at 488 pt wide is about 70 pt tall.
        #expect(abs(size.width - 488) < 0.5, "graph was \(size)")
        #expect(size.height > 60 && size.height < 80, "graph was \(size)")
    }

    @Test func widgetGraphsRespectTheirCap() throws {
        let cal = try ScreenshotTests.garo().calendar
        let small = graphSize(ContributionGraphView(days: cal.lastWeeks(12), theme: .green, showLabels: false, interactive: false, maxHeight: 58),
                              proposing: CGSize(width: 138, height: 0))
        #expect(small.height > 40 && small.height <= 58, "small widget graph was \(small)")
        let large = graphSize(ContributionGraphView(days: cal.lastWeeks(26), theme: .green, showLabels: true, interactive: false, maxHeight: 92),
                              proposing: CGSize(width: 332, height: 0))
        #expect(large.height > 60 && large.height <= 92, "large widget graph was \(large)")
    }

    /// Opens a real NSPopover on screen, exactly like the app, checks the graph was laid out with real
    /// height (in 1.0.0 it got almost none), and saves a screenshot of the live pixels.
    @Test(.enabled(if: NSScreen.main != nil), arguments: [false, true])
    func livePopover(dark: Bool) throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let screenshots = ScreenshotTests()
        let model = try screenshots.model(favorites: ["garoknows", "mira-builds", "nightshift-dev"])
        // Pick the opposite of whatever the Mac uses half the time, like a user choosing Light or Dark in Settings.
        model.appearance = dark ? .dark : .light

        let anchor = NSWindow(contentRect: NSRect(x: 200, y: 900, width: 60, height: 30), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        anchor.isReleasedWhenClosed = false
        anchor.orderFrontRegardless()
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
        model.applyAppearance(to: popover)
        AspectSizer.lastPlacedSize = .zero
        popover.show(relativeTo: anchor.contentView!.bounds, of: anchor.contentView!, preferredEdge: .minY)
        model.applyAppearance(to: popover)
        defer { popover.close(); anchor.close() }
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))

        let content = try #require(popover.contentViewController?.view)
        let graph = AspectSizer.lastPlacedSize
        #expect(graph.width > 450 && graph.height > 60, "graph in the live popover was laid out at \(graph)")

        let window = try #require(content.window)
        let image = try #require(CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber),
                                                         [.boundsIgnoreFraming, .bestResolution]))
        let rep = NSBitmapImageRep(cgImage: image)

        // The popover's own background must follow the Appearance setting, or text becomes unreadable
        // (seen on a Dark Mac with Appearance set to Light). On any Mac, one of the two cases is the
        // opposite of the system mode. Sample an empty patch of background left of the quadrant.
        let brightness = averageBrightness(rep, x: 0.06...0.10, y: 0.50...0.53)
        if dark {
            #expect(brightness < 0.35, "Dark appearance but the popover background brightness is \(brightness)")
        } else {
            #expect(brightness > 0.65, "Light appearance but the popover background brightness is \(brightness)")
        }
        try rep.representation(using: .png, properties: [:])!
            .write(to: ScreenshotTests.outDir.appendingPathComponent("popover-live-\(dark ? "dark" : "light").png"))
    }

    /// Mean perceived brightness (0 = black, 1 = white) of a region given as fractions of the image size.
    func averageBrightness(_ rep: NSBitmapImageRep, x: ClosedRange<Double>, y: ClosedRange<Double>) -> Double {
        var total = 0.0, n = 0.0
        let w = Double(rep.pixelsWide), h = Double(rep.pixelsHigh)
        for px in Int(x.lowerBound * w)...Int(x.upperBound * w) {
            for py in Int(y.lowerBound * h)...Int(y.upperBound * h) {
                guard let c = rep.colorAt(x: px, y: py)?.usingColorSpace(.sRGB) else { continue }
                total += 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
                n += 1
            }
        }
        return n > 0 ? total / n : 0
    }
}
