import SwiftUI

/// GitHub's year graph: one column per week (Sunday on top), month labels and Mon/Wed/Fri labels.
/// Drawn with Canvas so it stays fast in widgets, and scales to whatever width it's given.
public struct ContributionGraphView: View {
    let days: [ContributionDay]
    let theme: ColorTheme
    let showLabels: Bool
    let interactive: Bool
    let maxHeight: CGFloat?

    @Environment(\.colorScheme) private var scheme
    @State private var hovered: ContributionDay?
    @State private var hoverPoint: CGPoint = .zero

    /// - Parameter maxHeight: caps the height (the graph then scales down to keep its shape); used by widgets.
    public init(days: [ContributionDay], theme: ColorTheme, showLabels: Bool = true, interactive: Bool = true,
                maxHeight: CGFloat? = nil) {
        self.days = days
        self.theme = theme
        self.showLabels = showLabels
        self.interactive = interactive
        self.maxHeight = maxHeight
    }

    struct Layout {
        let first: CivilDate
        let columns: Int
        let padLeft: CGFloat
        let padTop: CGFloat
        let step: CGFloat
        let cell: CGFloat

        /// Nominal geometry (13 pt step, 10 pt cell) from the mockup; everything scales from it.
        static let nominalStep: CGFloat = 13
        static let nominalCell: CGFloat = 10

        init(days: [ContributionDay], labels: Bool, size: CGSize?) {
            let firstDay = days.first?.date ?? CivilDate(year: 2026, month: 1, day: 4)
            first = firstDay.adding(days: -firstDay.weekday)
            let lastDay = days.last?.date ?? firstDay
            columns = max(1, first.days(until: lastDay) / 7 + 1)
            let nominalPadLeft: CGFloat = labels ? 26 : 0
            let nominalPadTop: CGFloat = labels ? 14 : 0
            let nominalWidth = nominalPadLeft + CGFloat(columns) * Self.nominalStep - 3
            let scale = size.map { $0.width / nominalWidth } ?? 1
            padLeft = nominalPadLeft * scale
            padTop = nominalPadTop * scale
            step = Self.nominalStep * scale
            cell = Self.nominalCell * scale
        }

        var nominalWidth: CGFloat {
            padLeft + CGFloat(columns) * step - (step - cell)
        }

        var nominalAspect: CGFloat {
            let w = padLeft + CGFloat(columns) * step - (step - cell)
            let h = padTop + 7 * step - (step - cell)
            return w / h
        }

        func origin(of date: CivilDate) -> CGPoint {
            let offset = first.days(until: date)
            return CGPoint(x: padLeft + CGFloat(offset / 7) * step, y: padTop + CGFloat(offset % 7) * step)
        }

        func date(at point: CGPoint) -> CivilDate? {
            let col = Int(((point.x - padLeft) / step).rounded(.down))
            let row = Int(((point.y - padTop) / step).rounded(.down))
            guard col >= 0, col < columns, (0..<7).contains(row) else { return nil }
            return first.adding(days: col * 7 + row)
        }
    }

    public var body: some View {
        let nominal = Layout(days: days, labels: showLabels, size: nil)
        // Rigid sizing: height always follows width. A bare GeometryReader is flexible and can be
        // given zero height when a popover or widget measures its content, which hid the graph in 1.0.0.
        AspectSizer(aspect: nominal.nominalAspect, idealWidth: nominal.nominalWidth, maxHeight: maxHeight) {
            GeometryReader { proxy in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                guard interactive else { return }
                switch phase {
                case .active(let p):
                    hoverPoint = p
                    let layout = Layout(days: days, labels: showLabels, size: proxy.size)
                    hovered = layout.date(at: p).flatMap { d in days.first { $0.date == d } }
                case .ended:
                    hovered = nil
                }
            }
            .overlay(alignment: .topLeading) { tooltip(in: proxy.size) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contribution graph")
        .accessibilityChildren {
            // One element per day so VoiceOver can read "Oct 21, 7 contributions".
            ForEach(days, id: \.date) { day in
                Rectangle()
                    .accessibilityLabel("\(Format.short(day.date)), \(Format.contributions(day.count).lowercased())")
            }
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let layout = Layout(days: days, labels: showLabels, size: size)
        let colors = theme.levels(scheme)
        let palette = Palette(scheme)
        let radius = max(1, layout.cell * 0.2)

        for day in days {
            let o = layout.origin(of: day.date)
            let rect = CGRect(x: o.x, y: o.y, width: layout.cell, height: layout.cell)
            let path = Path(roundedRect: rect, cornerRadius: radius)
            context.fill(path, with: .color(colors[day.level]))
            context.stroke(path, with: .color(palette.cellStroke), lineWidth: 0.5)
            if day == hovered {
                context.stroke(path, with: .color(palette.fg.opacity(0.6)), lineWidth: 1)
            }
        }

        guard showLabels else { return }
        let fontSize = max(7, layout.step * 0.72)
        func label(_ s: String, _ p: CGPoint) {
            context.draw(Text(s).font(.system(size: fontSize)).foregroundColor(palette.muted), at: p, anchor: .bottomLeading)
        }
        var lastMonth = -1
        for col in 0..<layout.columns {
            let d = layout.first.adding(days: col * 7)
            if d.month != lastMonth, d.day <= 7, col < layout.columns - 1 {
                label(Format.monthName(d.month), CGPoint(x: layout.padLeft + CGFloat(col) * layout.step, y: layout.padTop - 2))
                lastMonth = d.month
            } else if lastMonth == -1 {
                lastMonth = d.month
            }
        }
        for (row, name) in [(1, "Mon"), (3, "Wed"), (5, "Fri")] {
            label(name, CGPoint(x: 0, y: layout.padTop + CGFloat(row) * layout.step + layout.cell))
        }
    }

    @ViewBuilder private func tooltip(in size: CGSize) -> some View {
        if interactive, let hovered {
            Text(Format.tooltip(hovered))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0x25292e)))
                .fixedSize()
                .offset(x: min(max(0, hoverPoint.x - 80), max(0, size.width - 190)), y: max(0, hoverPoint.y - 30))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// "Less ■■■■■ More"
public struct LegendView: View {
    let theme: ColorTheme
    @Environment(\.colorScheme) private var scheme

    public init(theme: ColorTheme) { self.theme = theme }

    public var body: some View {
        HStack(spacing: 3) {
            Text("Less")
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.color(level: i, scheme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Palette(scheme).cellStroke, lineWidth: 0.5))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.system(size: 11))
        .foregroundStyle(Palette(scheme).muted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color scale from fewer to more contributions")
    }
}

/// Sizes its content to the offered width (or `idealWidth` when none is offered) with a fixed aspect
/// ratio, and never gives up height to siblings. The graph always gets the room it needs.
struct AspectSizer: Layout {
    let aspect: CGFloat
    let idealWidth: CGFloat
    var maxHeight: CGFloat? = nil

    func size(for proposal: ProposedViewSize) -> CGSize {
        var width = proposal.width ?? idealWidth
        if !width.isFinite || width <= 0 { width = idealWidth }
        let ratio = max(aspect, 0.01)
        if let maxHeight, width / ratio > maxHeight {
            return CGSize(width: (maxHeight * ratio).rounded(.down), height: maxHeight)
        }
        return CGSize(width: width, height: (width / ratio).rounded(.up))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        size(for: proposal)
    }

    #if DEBUG
    /// Last size the graph was actually laid out at. Tests read it to prove the graph has room on screen.
    nonisolated(unsafe) static var lastPlacedSize: CGSize = .zero
    #endif

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        #if DEBUG
        Self.lastPlacedSize = bounds.size
        #endif
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
