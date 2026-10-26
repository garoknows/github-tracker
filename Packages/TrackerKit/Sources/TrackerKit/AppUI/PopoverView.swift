import SwiftUI

/// The menu bar popover: the current favorite's card, page dots with ◀ ▶, an Add row, and the footer.
public struct PopoverView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var adding = false
    @State private var addText = ""
    @State private var addError: String?
    @State private var addBusy = false
    @FocusState private var addFocused: Bool

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if model.favorites.isEmpty {
                WelcomeView(model: model)
            } else if model.screen == .settings {
                SettingsView(model: model)
            } else {
                cards
            }
        }
        .frame(width: 520)
        .preferredColorScheme(model.appearance.colorScheme)
    }

    private var cards: some View {
        let palette = Palette(scheme)
        return VStack(spacing: 0) {
            VStack(spacing: 12) {
                cardContent
                    .id(model.current)
                    .transition(.opacity)
                navigation
            }
            .padding(16)

            if adding { addRow.padding(.horizontal, 16).padding(.bottom, 10) }

            Divider()
            HStack(spacing: 8) {
                Button { adding.toggle(); addError = nil; addFocused = adding } label: { Label("Add", systemImage: "plus") }
                Button { Task { await model.refreshCurrent() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.current.map { model.refreshing.contains($0) } ?? true)
                Button { model.openCurrentProfile() } label: { Label("Open on GitHub", systemImage: "arrow.up.right") }
                Spacer()
                Button("Settings") { model.screen = .settings }.buttonStyle(.plain).padding(.horizontal, 6)
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).padding(.horizontal, 6)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(palette.fg)
        }
        .animation(.easeInOut(duration: 0.18), value: model.index)
    }

    @ViewBuilder private var cardContent: some View {
        if let login = model.current {
            if let snap = model.results[login]?.snapshot {
                ProfileCardView(snapshot: snap, theme: model.theme,
                                offlineMessage: model.offlineMessage(for: login),
                                openSettings: { model.screen = .settings })
            } else if model.refreshing.contains(login) || model.results[login] == nil {
                ProgressView("Loading @\(login)…").frame(maxWidth: .infinity, minHeight: 360)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.title)
                    Text(model.results[login]?.error?.errorDescription ?? "Couldn't load @\(login).")
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await model.refresh(login) } }
                }
                .foregroundStyle(Palette(scheme).muted)
                .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
    }

    private var navigation: some View {
        HStack(spacing: 8) {
            navButton("arrowtriangle.left.fill", "Previous favorite") { model.previous() }
            HStack(spacing: 6) {
                ForEach(Array(model.favorites.enumerated()), id: \.offset) { i, login in
                    Button { model.index = i } label: {
                        Circle()
                            .fill(i == model.index ? Palette(scheme).fg : Palette(scheme).muted.opacity(0.45))
                            .frame(width: 7, height: 7)
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show @\(login)")
                    .accessibilityAddTraits(i == model.index ? .isSelected : [])
                }
            }
            navButton("arrowtriangle.right.fill", "Next favorite") { model.next() }
        }
        .opacity(model.favorites.count > 1 ? 1 : 0.4)
        .disabled(model.favorites.count < 2)
    }

    private func navButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Palette(scheme).surface))
                .overlay(Circle().strokeBorder(Palette(scheme).border))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette(scheme).fg)
        .accessibilityLabel(label)
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Username, @handle, or github.com/name", text: $addText)
                    .textFieldStyle(.roundedBorder)
                    .focused($addFocused)
                    .onSubmit(submitAdd)
                    .accessibilityLabel("GitHub username")
                Button("Add", action: submitAdd).keyboardShortcut(.defaultAction).disabled(addBusy)
                Button("Cancel") { adding = false; addText = ""; addError = nil }
            }
            if addBusy { ProgressView().controlSize(.small) }
            if let addError {
                Text(addError).font(.system(size: 12)).foregroundStyle(Color(hex: scheme == .dark ? 0xff7b72 : 0xcf222e))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private func submitAdd() {
        addBusy = true
        Task {
            let error = await model.add(addText)
            addBusy = false
            addError = error
            if error == nil {
                adding = false
                addText = ""
            }
        }
    }
}

/// First launch: one friendly field.
public struct WelcomeView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var text = ""
    @State private var error: String?
    @State private var busy = false

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        let palette = Palette(scheme)
        VStack(spacing: 14) {
            BrandMark(theme: model.theme).frame(width: 44, height: 44)
            Text("Welcome to Tracker for GitHub").font(.system(size: 18, weight: .semibold)).foregroundStyle(palette.fg)
            Text("Type a GitHub username to see their contribution graph and activity overview. You can add more people later.")
                .font(.system(size: 13)).foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("garoknows", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
                    .accessibilityLabel("GitHub username")
                Button("Add", action: submit).keyboardShortcut(.defaultAction).disabled(busy)
            }
            if busy { ProgressView().controlSize(.small) }
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: scheme == .dark ? 0xff7b72 : 0xcf222e))
            }
            Text("No account needed. Talks only to GitHub.")
                .font(.system(size: 11)).foregroundStyle(palette.muted)
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(palette.muted)
            }
        }
        .padding(24)
    }

    private func submit() {
        busy = true
        Task {
            error = await model.add(text)
            busy = false
        }
    }
}

/// The 3×3 green squares logo.
public struct BrandMark: View {
    let theme: ColorTheme
    @Environment(\.colorScheme) private var scheme
    public init(theme: ColorTheme) { self.theme = theme }
    public var body: some View {
        let levels = [1, 3, 2, 4, 2, 0, 3, 1, 4]
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3).fill(theme.color(level: levels[r * 3 + c], scheme))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
