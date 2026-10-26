import SwiftUI

/// The three widget layouts from the mockup. They live here (not in the widget target) so the
/// snapshot tests can render them; the widget passes its interactive ◀ ▶ buttons in as `navigation`.
public enum WidgetSize: String, CaseIterable, Sendable {
    case small, medium, large
}

public struct WidgetCardView<Navigation: View>: View {
    let snapshot: ProfileSnapshot?
    let size: WidgetSize
    let theme: ColorTheme
    let index: Int
    let count: Int
    let today: CivilDate
    let avatarData: Data?
    let navigation: Navigation
    @Environment(\.colorScheme) private var scheme

    public init(snapshot: ProfileSnapshot?, size: WidgetSize, theme: ColorTheme, index: Int = 0, count: Int = 1,
                today: CivilDate = CivilDate(Date()), avatarData: Data? = nil,
                @ViewBuilder navigation: () -> Navigation) {
        self.snapshot = snapshot
        self.size = size
        self.theme = theme
        self.index = index
        self.count = count
        self.today = today
        self.avatarData = avatarData
        self.navigation = navigation()
    }

    public var body: some View {
        if let snapshot {
            content(snapshot)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill").font(.title2).foregroundStyle(theme.accent(scheme))
                Text("Right-click and choose Edit Widget to add a GitHub username.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette(scheme).muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func content(_ snap: ProfileSnapshot) -> some View {
        let s = ContributionStats(calendar: snap.calendar, today: today)
        let palette = Palette(scheme)
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                ProfileHeader(profile: snap.profile, avatarData: avatarData, avatarSize: 30)
                ContributionGraphView(days: snap.calendar.lastWeeks(12), theme: theme, showLabels: false, interactive: false)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.total.formatted()).font(.system(size: 26, weight: .bold)).foregroundStyle(palette.fg)
                    Text("this year").font(.system(size: 12)).foregroundStyle(palette.muted)
                }
                .accessibilityElement(children: .combine)
            }
        case .medium:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    ProfileHeader(profile: snap.profile, avatarData: avatarData, avatarSize: 30)
                    Spacer()
                    navigation
                }
                ContributionGraphView(days: snap.calendar.lastWeeks(20), theme: theme, showLabels: false, interactive: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    stat("\(s.total.formatted())", "this year")
                    stat("\(s.currentStreak.length)", "day streak")
                    HStack(spacing: 3) {
                        Text("Best").foregroundStyle(palette.muted)
                        Text("\(s.bestDay?.count ?? 0)").bold().foregroundStyle(palette.fg)
                    }
                    Spacer()
                }
                .font(.system(size: 12))
                if count > 1 { PageDots(count: count, index: index, size: 5).frame(maxWidth: .infinity) }
            }
        case .large:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ProfileHeader(profile: snap.profile, avatarData: avatarData, avatarSize: 30)
                    Spacer()
                    navigation
                }
                ContributionGraphView(days: snap.calendar.lastWeeks(26), theme: theme, showLabels: true, interactive: false)
                HStack(spacing: 14) {
                    stat("\(s.total.formatted())", "this year")
                    stat("\(s.currentStreak.length)", "current")
                    stat("\(s.longestStreak.length)", "longest")
                    Spacer()
                }
                .font(.system(size: 12))
                Group {
                    if let o = snap.overview.overview {
                        QuadrantView(overview: o, theme: theme)
                    } else {
                        QuadrantPlaceholder(state: snap.overview)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if count > 1 { PageDots(count: count, index: index, size: 5).frame(maxWidth: .infinity) }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(value).bold().foregroundStyle(Palette(scheme).fg)
            Text(label).foregroundStyle(Palette(scheme).muted)
        }
        .accessibilityElement(children: .combine)
    }
}

extension WidgetCardView where Navigation == EmptyView {
    public init(snapshot: ProfileSnapshot?, size: WidgetSize, theme: ColorTheme, index: Int = 0, count: Int = 1,
                today: CivilDate = CivilDate(Date()), avatarData: Data? = nil) {
        self.init(snapshot: snapshot, size: size, theme: theme, index: index, count: count, today: today,
                  avatarData: avatarData) { EmptyView() }
    }
}

/// Static ◀ ▶ circles used in screenshots; the widget swaps in real AppIntent buttons.
public struct NavCircles: View {
    @Environment(\.colorScheme) private var scheme
    public init() {}
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(["arrowtriangle.left.fill", "arrowtriangle.right.fill"], id: \.self) { name in
                Image(systemName: name)
                    .font(.system(size: 9))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Palette(scheme).surface))
                    .foregroundStyle(Palette(scheme).fg)
            }
        }
    }
}
