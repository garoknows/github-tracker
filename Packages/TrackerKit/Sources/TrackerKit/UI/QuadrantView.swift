import SwiftUI

/// GitHub's Activity overview cross: Code review up, Issues right, Pull requests down, Commits left,
/// with the filled shape and the percentage at each axis.
public struct QuadrantView: View {
    let overview: ActivityOverview
    let theme: ColorTheme
    @Environment(\.colorScheme) private var scheme

    public init(overview: ActivityOverview, theme: ColorTheme) {
        self.overview = overview
        self.theme = theme
    }

    public var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = s * 0.23
            let colors = theme.levels(scheme)
            let line = colors[3]
            let palette = Palette(scheme)
            let o = overview

            var axes = Path()
            axes.move(to: CGPoint(x: c.x, y: c.y - r)); axes.addLine(to: CGPoint(x: c.x, y: c.y + r))
            axes.move(to: CGPoint(x: c.x - r, y: c.y)); axes.addLine(to: CGPoint(x: c.x + r, y: c.y))
            context.stroke(axes, with: .color(line), lineWidth: max(1.5, s / 100))

            let values = [o.codeReview, o.issues, o.pullRequests, o.commits]
            let points = [
                CGPoint(x: c.x, y: c.y - r * CGFloat(o.codeReview) / 100),
                CGPoint(x: c.x + r * CGFloat(o.issues) / 100, y: c.y),
                CGPoint(x: c.x, y: c.y + r * CGFloat(o.pullRequests) / 100),
                CGPoint(x: c.x - r * CGFloat(o.commits) / 100, y: c.y)
            ]
            var shape = Path()
            shape.addLines(points)
            shape.closeSubpath()
            context.fill(shape, with: .color(colors[2].opacity(0.55)))
            context.stroke(shape, with: .color(line), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            for (p, v) in zip(points, values) where v > 0 {
                let dot = Path(ellipseIn: CGRect(x: p.x - 3.2, y: p.y - 3.2, width: 6.4, height: 6.4))
                context.fill(dot, with: .color(palette.surface))
                context.stroke(dot, with: .color(line), lineWidth: 2)
            }

            let font = max(9, s * 0.06)
            // Percentage on top, axis name below, both hugging the end of the axis.
            func label(_ pct: Int, _ name: String, at p: CGPoint, anchor: UnitPoint) {
                let lineHeight = font * 1.25
                let nameText = Text(name).font(.system(size: font)).foregroundColor(palette.muted)
                let pctText = Text("\(pct)%").font(.system(size: font, weight: .semibold)).foregroundColor(palette.fg)
                let rows: [Text] = pct > 0 ? [pctText, nameText] : [nameText]
                let blockHeight = lineHeight * CGFloat(rows.count)
                let top: CGFloat = switch anchor {
                case .bottom: p.y - blockHeight
                case .top: p.y
                default: p.y - blockHeight / 2
                }
                let rowAnchor: UnitPoint = anchor == .trailing ? .trailing : anchor == .leading ? .leading : .center
                for (i, row) in rows.enumerated() {
                    context.draw(row, at: CGPoint(x: p.x, y: top + lineHeight * (CGFloat(i) + 0.5)), anchor: rowAnchor)
                }
            }
            label(o.codeReview, "Code review", at: CGPoint(x: c.x, y: c.y - r - 4), anchor: .bottom)
            label(o.pullRequests, "Pull requests", at: CGPoint(x: c.x, y: c.y + r + 4), anchor: .top)
            label(o.commits, "Commits", at: CGPoint(x: c.x - r - 6, y: c.y), anchor: .trailing)
            label(o.issues, "Issues", at: CGPoint(x: c.x + r + 6, y: c.y), anchor: .leading)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity overview: \(overview.commits)% commits, \(overview.issues)% issues, \(overview.pullRequests)% pull requests, \(overview.codeReview)% code review")
    }
}

/// Calm dashed box shown instead of the chart, with the reason.
public struct QuadrantPlaceholder: View {
    let state: OverviewState
    let openSettings: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    public init(state: OverviewState, openSettings: (() -> Void)? = nil) {
        self.state = state
        self.openSettings = openSettings
    }

    public var body: some View {
        let palette = Palette(scheme)
        VStack(spacing: 8) {
            Text(state.placeholderMessage ?? "")
                .multilineTextAlignment(.center)
            if state == .needsToken, let openSettings {
                Button("Open Settings", action: openSettings)
                    .controlSize(.small)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.muted)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}
