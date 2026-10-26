import AppKit
import SwiftUI
import TrackerKit

@main
struct TrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only app: no windows. The popover is managed by AppDelegate.
        Settings { EmptyView() }
    }
}

/// Owns the status item and popover, and routes arrow keys and two-finger swipes to the model.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var swipeAccumulator: CGFloat = 0
    private var swipeHandled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.setAccessibilityLabel("Tracker for GitHub")

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))

        model.onChange = { [weak self] in
            guard let self else { return }
            self.updateIcon()
            self.model.applyAppearance(to: self.popover)
        }
        model.onClose = { [weak self] in self?.popover.performClose(nil) }
        updateIcon()
        model.applyAppearance(to: popover)
        model.start()

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(appearanceChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil)

        // First run: open the welcome popover right away.
        if model.favorites.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showPopover() }
        }
    }

    @objc private func appearanceChanged() { updateIcon() }

    private func updateIcon() {
        let dark = statusItem.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        statusItem.button?.image = MenuBarIcon.image(style: model.iconStyle, snapshot: model.primarySnapshot,
                                                    theme: model.theme, dark: dark)
        statusItem.button?.toolTip = model.primary.map { "Tracker for GitHub: @\($0)" } ?? "Tracker for GitHub"
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        model.screen = .cards
        model.index = 0
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        model.applyAppearance(to: popover)
        popover.contentViewController?.view.window?.makeKey()
        startMonitoring()
    }

    func popoverDidClose(_ notification: Notification) {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }

    private func startMonitoring() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
            guard let self, self.popover.isShown, self.model.screen == .cards else { return event }
            if event.type == .keyDown {
                // Leave arrows alone while typing in a text field.
                if event.window?.firstResponder is NSTextView { return event }
                switch event.keyCode {
                case 123: self.model.previous(); return nil // ←
                case 124: self.model.next(); return nil     // →
                default: return event
                }
            }
            return self.handleSwipe(event) ? nil : event
        }
    }

    /// Two-finger horizontal trackpad swipe flips favorites (one flip per gesture).
    private func handleSwipe(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false }
        if event.phase == .began {
            swipeAccumulator = 0
            swipeHandled = false
        }
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) || swipeAccumulator != 0 else { return false }
        // Track finger movement regardless of the "natural scrolling" setting.
        swipeAccumulator += event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        if !swipeHandled, abs(swipeAccumulator) > 60 {
            swipeHandled = true
            // Fingers moving left show the next card, like turning a page.
            swipeAccumulator < 0 ? model.next() : model.previous()
        }
        if event.phase == .ended || event.phase == .cancelled {
            swipeAccumulator = 0
            swipeHandled = false
        }
        return true
    }
}
