import SwiftUI

/// Settings, shown inside the popover like the mockup.
public struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var token = ""
    @State private var addText = ""
    @State private var addError: String?

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        let palette = Palette(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Settings").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("Done") { model.screen = .cards }.keyboardShortcut(.cancelAction)
                }
                .padding(.bottom, 4)

                section("Favorites")
                VStack(spacing: 6) {
                    ForEach(Array(model.favorites.enumerated()), id: \.element) { i, login in
                        favoriteRow(login, isPrimary: i == 0, isFirst: i == 0)
                    }
                }
                HStack {
                    TextField("Add username, @handle, or github.com/name", text: $addText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add).disabled(model.favorites.count >= AppModel.maxFavorites)
                }
                if let addError { errorText(addError) }
                note("Up to 10 favorites. The Primary profile drives the menu bar icon.")

                section("GitHub token (optional)")
                HStack {
                    Text("Read-only token").frame(width: 120, alignment: .leading)
                    SecureField(model.hasToken ? "Saved in Keychain" : "github_pat_…", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("GitHub token")
                    Button("Test token") {
                        let t = token
                        token = ""
                        Task { await model.saveAndTestToken(t) }
                    }
                    .disabled(token.isEmpty)
                    if model.hasToken { Button("Remove") { model.removeToken() } }
                }
                note(model.tokenStatus ?? "Only needed when a profile's quadrant chart doesn't load publicly. Stored in your Mac's Keychain, sent only to GitHub.")
                HStack(spacing: 4) {
                    note("Needs no permissions: a fine-grained token with only public access, or a classic token with no scopes.")
                    Link("Create one", destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!)
                        .font(.system(size: 12))
                }

                section("General")
                row("Refresh every") {
                    Picker("Refresh every", selection: $model.interval) {
                        ForEach(RefreshInterval.allCases) { Text($0.name).tag($0) }
                    }
                    .labelsHidden().frame(width: 150)
                }
                row("Launch at login") {
                    Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
                if let e = model.launchAtLoginError { errorText(e) }
                row("Menu bar icon") {
                    Picker("Menu bar icon", selection: $model.iconStyle) {
                        ForEach(MenuBarIconStyle.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                }
                row("Appearance") {
                    Picker("Appearance", selection: $model.appearance) {
                        ForEach(Appearance.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                }

                section("Color theme")
                HStack(spacing: 8) {
                    ForEach(ColorTheme.allCases) { theme in
                        Button { model.theme = theme } label: {
                            HStack(spacing: 6) {
                                HStack(spacing: 2) {
                                    ForEach(1..<5, id: \.self) { l in
                                        RoundedRectangle(cornerRadius: 2).fill(theme.color(level: l, scheme)).frame(width: 7, height: 14)
                                    }
                                }
                                Text(theme.name).font(.system(size: 12))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(palette.surface))
                            .overlay(Capsule().strokeBorder(model.theme == theme ? Color.accentColor : palette.border,
                                                            lineWidth: model.theme == theme ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(theme.name) theme")
                        .accessibilityAddTraits(model.theme == theme ? .isSelected : [])
                    }
                }

                section("About")
                HStack(spacing: 4) {
                    note("Version \(AppModel.version) · MIT license ·")
                    Link("github.com/garoknows/github-tracker", destination: AppModel.repoURL).font(.system(size: 12))
                    Button("Check for updates") { model.checkForUpdates() }.controlSize(.small)
                }
                HStack(spacing: 10) {
                    Link("Report an issue", destination: AppModel.repoURL.appendingPathComponent("issues"))
                    Link("License", destination: AppModel.repoURL.appendingPathComponent("blob/main/LICENSE"))
                }
                .font(.system(size: 12))
                note("Not affiliated with or endorsed by GitHub, Inc.")
            }
            .padding(16)
        }
        .frame(height: 560)
    }

    private func favoriteRow(_ login: String, isPrimary: Bool, isFirst: Bool) -> some View {
        let palette = Palette(scheme)
        let profile = model.results[login]?.snapshot?.profile ?? GitHubProfile(login: login, name: nil, avatarURL: nil)
        return HStack(spacing: 8) {
            AvatarView(profile: profile, size: 24)
            Text(profile.displayName) + Text(" @\(login)").foregroundColor(palette.muted)
            Spacer()
            if isPrimary {
                Text("Primary").font(.system(size: 11)).foregroundStyle(ColorTheme.green.accent(scheme))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(Capsule().strokeBorder(ColorTheme.green.accent(scheme)))
            } else {
                Button("Make primary") { model.makePrimary(login) }.controlSize(.small)
            }
            Button { model.moveUp(login) } label: { Image(systemName: "arrow.up") }
                .controlSize(.small).disabled(isFirst).accessibilityLabel("Move @\(login) up")
            Button { model.remove(login) } label: { Image(systemName: "xmark") }
                .controlSize(.small).disabled(model.favorites.count < 2).accessibilityLabel("Remove @\(login)")
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.border))
    }

    private func add() {
        Task {
            addError = await model.add(addText)
            if addError == nil { addText = "" }
            model.screen = .settings
        }
    }

    private func section(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette(scheme).muted)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Palette(scheme).muted).fixedSize(horizontal: false, vertical: true)
    }

    private func errorText(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Color(hex: scheme == .dark ? 0xff7b72 : 0xcf222e))
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).frame(width: 120, alignment: .leading)
            content()
            Spacer()
        }
        .font(.system(size: 13))
    }
}
