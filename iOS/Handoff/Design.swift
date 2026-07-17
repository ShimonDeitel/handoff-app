import SwiftUI

/// "Constellation of family": dusty lavender + warm stone grey, calm and grounded rather than
/// clinical. Not Rota's hand-chalked green/coral, not Field's charcoal/orange lens barrel — a
/// soft, low-saturation palette meant to feel like a quiet family photo album, not a dashboard.
enum HandoffColor {
    static let canvas = Color(light: Color(hex: 0xF4EFEA), dark: Color(hex: 0x201C26))
    static let panel = Color(light: Color(hex: 0xFBF8F4), dark: Color(hex: 0x2A2530))
    static let ink = Color(light: Color(hex: 0x342E3D), dark: Color(hex: 0xF1EBF2))
    static let inkMuted = Color(light: Color(hex: 0x7C7488), dark: Color(hex: 0xA79FB3))
    static let hairline = Color(light: Color(hex: 0xE3DAD0), dark: Color(hex: 0x3A3542))

    /// Primary accent — dusty lavender.
    static let lavender = Color(hex: 0x9B8AC4)
    static let lavenderDeep = Color(hex: 0x76639E)
    /// Secondary accent — warm stone grey, used for the parent node and neutral chrome.
    static let stone = Color(light: Color(hex: 0xC9BEB0), dark: Color(hex: 0x6E6459))
    static let stoneDeep = Color(light: Color(hex: 0xA79A88), dark: Color(hex: 0x8C8071))
    /// The traveling "handoff glow" — warm amber-gold, distinct from lavender so the pulse
    /// animation reads clearly against the constellation's arcs.
    static let glow = Color(hex: 0xE8B975)
    static let waiting = Color(hex: 0xC9793F)
    static let good = Color(hex: 0x6E9B7B)

    /// Fixed 6-hue sibling-node palette, cycled by rotation order so each sibling keeps a
    /// stable, distinct ring color across launches.
    static let siblingPalette: [Color] = [
        Color(hex: 0x9B8AC4), // lavender
        Color(hex: 0xC98A6B), // terracotta
        Color(hex: 0x6E9B9B), // dusty teal
        Color(hex: 0xB98CAE), // mauve
        Color(hex: 0x8FA36E), // sage
        Color(hex: 0xC9A363)  // ochre
    ]

    static func sibling(_ index: Int) -> Color {
        siblingPalette[((index % siblingPalette.count) + siblingPalette.count) % siblingPalette.count]
    }
}

/// Warm serif for headlines (photo-album, personal feel), plain system for body/labels so long
/// visit-log text stays easy to read.
enum HandoffFont {
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func headline(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func value(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .regular, design: .default) }
    static func tag(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium, design: .default) }
    static func caption(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium, design: .default) }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
