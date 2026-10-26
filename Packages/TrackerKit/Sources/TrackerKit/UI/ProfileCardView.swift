import SwiftUI

/// Round avatar: the real picture when we have it, otherwise initials on a stable color.
public struct AvatarView: View {
    let profile: GitHubProfile
    let imageData: Data?
    let size: CGFloat

    public init(profile: GitHubProfile, imageData: Data? = nil, size: CGFloat = 40) {
        self.profile = profile
        self.imageData = imageData
        self.size = size
    }

    public var body: some View {
        Group {
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image).resizable().scaledToFill()
            } else if imageData == nil, let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { initials }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Circle().fill(avatarColor(for: profile.login))
            .overlay(Text(profile.initials).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.white))
    }
}

public struct ProfileHeader: View {
    let profile: GitHubProfile
    let avatarData: Data?
    let avatarSize: CGFloat
    @Environment(\.colorScheme) private var scheme

    public init(profile: GitHubProfile, avatarData: Data? = nil, avatarSize: CGFloat = 40) {
        self.profile = profile
        self.avatarData = avatarData
        self.avatarSize = avatarSize
    }

    public var body: some View {
        HStack(spacing: 10) {
            AvatarView(profile: profile, imageData: avatarData, size: avatarSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.displayName)
                    .font(.system(size: avatarSize * 0.4, weight: .semibold))
                    .foregroundStyle(Palette(scheme).fg)
                Text("@\(profile.login)")
                    .font(.system(size: avatarSize * 0.33))
                    .foregroundStyle(Palette(scheme).muted)
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

public struct StatTile: View {
    let title: String
    let value: String
    let subtitle: String
    let theme: ColorTheme
    @Environment(\.colorScheme) private var scheme

    public init(_ title: String, value: String, subtitle: String, theme: ColorTheme) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.theme = theme
    }

    public var body: some View {
        let palette = Palette(scheme)
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).foregroundStyle(palette.muted)
            Text(value).font(.system(size: 16, weight: .bold)).foregroundStyle(theme.accent(scheme))
            Text(subtitle).font(.system(size: 10.5)).foregroundStyle(palette.muted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.border))
        .accessibilityElement(children: .combine)
    }
}

public struct PageDots: View {
    let count: Int
    let index: Int
    let size: CGFloat
    @Environment(\.colorScheme) private var scheme

    public init(count: Int, index: Int, size: CGFloat = 6) {
        self.count = count
        self.index = index
        self.size = size
    }

    public var body: some View {
        HStack(spacing: size * 0.8) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Palette(scheme).fg : Palette(scheme).muted.opacity(0.45))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Favorite \(index + 1) of \(count)")
    }
}

/// The full card shown in the menu bar popover.
public struct ProfileCardView: View {
    let snapshot: ProfileSnapshot
    let theme: ColorTheme
    let today: CivilDate
    let offlineMessage: String?
    let now: Date
    let openSettings: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    public init(snapshot: ProfileSnapshot, theme: ColorTheme, today: CivilDate = CivilDate(Date()),
                offlineMessage: String? = nil, now: Date = Date(), openSettings: (() -> Void)? = nil) {
        self.snapshot = snapshot
        self.theme = theme
        self.today = today
        self.offlineMessage = offlineMessage
        self.now = now
        self.openSettings = openSettings
    }

    public var body: some View {
        let s = ContributionStats(calendar: snapshot.calendar, today: today)
        let palette = Palette(scheme)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ProfileHeader(profile: snapshot.profile)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Updated \(Format.age(since: snapshot.fetchedAt, now: now))")
                        .font(.system(size: 11)).foregroundStyle(palette.muted)
                    if let offlineMessage {
                        Text(offlineMessage)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: scheme == .dark ? 0xd29922 : 0x9a6700))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .overlay(Capsule().strokeBorder(Color(hex: scheme == .dark ? 0xd29922 : 0x9a6700).opacity(0.6)))
                            .help(offlineMessage)
                    }
                }
            }

            (Text(snapshot.calendar.total.formatted()).bold() + Text(" contributions in the last year"))
                .font(.system(size: 14))
                .foregroundStyle(palette.fg)

            VStack(alignment: .trailing, spacing: 6) {
                ContributionGraphView(days: snapshot.calendar.days, theme: theme)
                LegendView(theme: theme)
            }

            HStack(spacing: 6) {
                StatTile("Total", value: s.total.formatted(), subtitle: "last 12 months", theme: theme)
                StatTile("Best day", value: "\(s.bestDay?.count ?? 0)",
                         subtitle: s.bestDay.map { Format.short($0.date) } ?? "–", theme: theme)
                StatTile("Average", value: String(format: "%.2f", s.averagePerDay), subtitle: "per day", theme: theme)
                StatTile("Current streak", value: Format.days(s.currentStreak.length),
                         subtitle: s.currentStreak.length == 0 ? "no activity today"
                            : s.currentStreakEndsYesterday ? "ends yesterday" : "ends today", theme: theme)
                StatTile("Longest streak", value: Format.days(s.longestStreak.length),
                         subtitle: s.longestStreak.start.map { "\(Format.short($0)) – \(Format.short(s.longestStreak.end!))" } ?? "–",
                         theme: theme)
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity overview").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.fg)
                    Text(overviewBlurb)
                        .font(.system(size: 12)).foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    if let o = snapshot.overview.overview {
                        QuadrantView(overview: o, theme: theme).frame(width: 250, height: 200)
                    } else {
                        QuadrantPlaceholder(state: snapshot.overview, openSettings: openSettings).frame(width: 250, height: 170)
                    }
                }
            }
        }
    }

    private var overviewBlurb: String {
        switch snapshot.overview {
        case .available(_, .publicProfile):
            return "Share of \(snapshot.profile.displayName)'s activity this year across commits, issues, pull requests and code review."
        case .available(_, .graphQL):
            return "Share of \(snapshot.profile.displayName)'s public activity this year, computed from GitHub's API with your token."
        default:
            return "This chart appears when GitHub shares it for this profile."
        }
    }
}
