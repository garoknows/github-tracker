import SwiftUI

/// The four graph color themes from the approved mockup. Index 0 is "no contributions", 4 is the most.
public enum ColorTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case green, halloween, ocean, mono

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .green: "GitHub Green"
        case .halloween: "Halloween"
        case .ocean: "Ocean"
        case .mono: "Mono"
        }
    }

    public func levels(_ scheme: ColorScheme) -> [Color] {
        let hex: [UInt32]
        switch (self, scheme) {
        case (.green, .dark): hex = [0x151b23, 0x033a16, 0x196c2e, 0x2ea043, 0x56d364]
        case (.green, _): hex = [0xeff2f5, 0xaceebb, 0x4ac26b, 0x2da44e, 0x116329]
        case (.halloween, .dark): hex = [0x151b23, 0x631c03, 0xbd561d, 0xfa7a18, 0xfddf68]
        case (.halloween, _): hex = [0xeff2f5, 0xffee4a, 0xffc501, 0xfe9600, 0x03001c]
        case (.ocean, .dark): hex = [0x151b23, 0x0c2d6b, 0x1158c7, 0x388bfd, 0x79c0ff]
        case (.ocean, _): hex = [0xeff2f5, 0xb6e3ff, 0x54aeff, 0x0969da, 0x0a3069]
        case (.mono, .dark): hex = [0x151b23, 0x3d444d, 0x656c76, 0x9198a1, 0xd1d7e0]
        case (.mono, _): hex = [0xeff2f5, 0xc8ccd1, 0x9198a1, 0x59636e, 0x1f2328]
        }
        return hex.map { Color(hex: $0) }
    }

    public func color(level: Int, _ scheme: ColorScheme) -> Color {
        levels(scheme)[max(0, min(4, level))]
    }

    /// The accent used for big numbers and the quadrant lines.
    public func accent(_ scheme: ColorScheme) -> Color {
        if self == .green { return Color(hex: scheme == .dark ? 0x3fb950 : 0x1a7f37) }
        return levels(scheme)[scheme == .dark ? 4 : 3]
    }
}

/// Primer-style neutrals matching the mockup.
public struct Palette: Sendable {
    public let fg: Color
    public let muted: Color
    public let surface: Color
    public let border: Color
    public let cellStroke: Color

    public init(_ scheme: ColorScheme) {
        if scheme == .dark {
            fg = Color(hex: 0xf0f6fc)
            muted = Color(hex: 0x9198a1)
            surface = Color(hex: 0x0d1117)
            border = Color(hex: 0xf0f6fc, opacity: 0.1)
        } else {
            fg = Color(hex: 0x1f2328)
            muted = Color(hex: 0x59636e)
            surface = Color.white
            border = Color(hex: 0x1f2328, opacity: 0.12)
        }
        cellStroke = Color.gray.opacity(0.12)
    }
}

public enum Appearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Color {
    public init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

/// Deterministic avatar background for the initials placeholder (same palette as the mockup).
public func avatarColor(for login: String) -> Color {
    let colors: [UInt32] = [0x1f883d, 0x8250df, 0xbf3989, 0x0969da, 0xbc4c00, 0x1b7c83, 0xcf222e, 0x6639ba]
    var h: UInt32 = 2_166_136_261
    for b in login.lowercased().utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
    return Color(hex: colors[Int(h % UInt32(colors.count))])
}
