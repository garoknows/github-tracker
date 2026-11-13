import Foundation
import SwiftUI
import Testing
@testable import TrackerKit

/// The widget total covers the last 12 months, like the popover's "in the last year", not the calendar year.
@Suite("Widget labels")
struct WidgetLabelTests {
    @Test func totalSaysPastYear() {
        #expect(WidgetCardView<EmptyView>.totalLabel == "past year")
    }

    /// Every widget size draws its total with that one label; the old wording never comes back.
    @Test func noWidgetSaysThisYear() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/TrackerKit/UI/WidgetLayouts.swift")
        let code = try String(contentsOf: source, encoding: .utf8)
        #expect(!code.contains("this year"))
        // Small, medium and large each show the total with the shared label.
        #expect(code.components(separatedBy: "Self.totalLabel").count - 1 == 3)
    }
}

/// Tests that put real windows on screen only run when asked to (TRACKER_LIVE_UI_TESTS=1).
@Suite("Live UI tests are opt-in")
struct LiveUITestGateTests {
    @Test func offUnlessTheVariableIsOne() {
        #expect(!LiveUITests.enabled(environment: [:], hasScreen: true))
        #expect(!LiveUITests.enabled(environment: ["TRACKER_LIVE_UI_TESTS": "0"], hasScreen: true))
        #expect(!LiveUITests.enabled(environment: ["TRACKER_LIVE_UI_TESTS": "yes"], hasScreen: true))
        #expect(!LiveUITests.enabled(environment: ["TRACKER_LIVE_UI_TESTS": "1"], hasScreen: false))
        #expect(LiveUITests.enabled(environment: ["TRACKER_LIVE_UI_TESTS": "1"], hasScreen: true))
    }
}
