import SwiftUI

enum ThemeOption: String, CaseIterable, Identifiable {
    case morning, vinyl, ocean, studio

    var id: String { rawValue }

    var name: String {
        switch self {
        case .morning: "晨光唱片"
        case .vinyl: "夜色黑胶"
        case .ocean: "深海电台"
        case .studio: "复古工作室"
        }
    }

    var isDark: Bool { self == .vinyl || self == .ocean }

    var palette: ThemePalette {
        switch self {
        case .morning:
            ThemePalette(
                canvas: Color(hex: 0xFCFCFA), sidebar: Color(hex: 0xF2F5F0),
                inspector: Color(hex: 0xF0F4EF), player: Color(hex: 0xEDF3EC),
                line: Color(hex: 0xDCE3DB), text: Color(hex: 0x2B4735),
                muted: Color(hex: 0x6D7E70), accent: Color(hex: 0x6C9278),
                accentDark: Color(hex: 0x385C42), selected: Color(hex: 0xDFE9DF),
                onAccent: .white, recordInk: Color(hex: 0x2D4B37),
                hero: [Color(hex: 0xE3E8DC), Color(hex: 0xCBDACB), Color(hex: 0x9FB9A4)],
                artwork: [Color(hex: 0xBBC9AB), Color(hex: 0x526F5E)],
                recordLabel: [Color(hex: 0xDFE8D6), Color(hex: 0x92AC94), Color(hex: 0x4E7459)]
            )
        case .vinyl:
            ThemePalette(
                canvas: Color(hex: 0x1B1C1B), sidebar: Color(hex: 0x232522),
                inspector: Color(hex: 0x252723), player: Color(hex: 0x222720),
                line: Color(hex: 0x3B403A), text: Color(hex: 0xF1EDE5),
                muted: Color(hex: 0xACB0A8), accent: Color(hex: 0xC79568),
                accentDark: Color(hex: 0xE6B98B), selected: Color(hex: 0x473B31),
                onAccent: Color(hex: 0x241B16), recordInk: Color(hex: 0x4D3424),
                hero: [Color(hex: 0x493A32), Color(hex: 0x6C5140), Color(hex: 0x956C4C)],
                artwork: [Color(hex: 0xA2825C), Color(hex: 0x534332)],
                recordLabel: [Color(hex: 0xE8D9BF), Color(hex: 0xB9966B), Color(hex: 0x745234)]
            )
        case .ocean:
            ThemePalette(
                canvas: Color(hex: 0x101D28), sidebar: Color(hex: 0x14242F),
                inspector: Color(hex: 0x1A2C39), player: Color(hex: 0x162631),
                line: Color(hex: 0x2E4653), text: Color(hex: 0xE3EFF1),
                muted: Color(hex: 0x9CB5BE), accent: Color(hex: 0x8AB9C8),
                accentDark: Color(hex: 0xABD5DE), selected: Color(hex: 0x25465B),
                onAccent: Color(hex: 0x13212A), recordInk: Color(hex: 0x1A3D4D),
                hero: [Color(hex: 0x1D3948), Color(hex: 0x1A4654), Color(hex: 0x235970)],
                artwork: [Color(hex: 0x7FAFB5), Color(hex: 0x315F70)],
                recordLabel: [Color(hex: 0xC4DEE0), Color(hex: 0x6F9EAD), Color(hex: 0x365F78)]
            )
        case .studio:
            ThemePalette(
                canvas: Color(hex: 0xFBF7F1), sidebar: Color(hex: 0xEEE5DA),
                inspector: Color(hex: 0xF1E7DD), player: Color(hex: 0xE8DBCB),
                line: Color(hex: 0xD9C9B9), text: Color(hex: 0x604537),
                muted: Color(hex: 0x8B7567), accent: Color(hex: 0xB46C4A),
                accentDark: Color(hex: 0x7A3E2D), selected: Color(hex: 0xDFC8B7),
                onAccent: .white, recordInk: Color(hex: 0x643928),
                hero: [Color(hex: 0xE8D3C0), Color(hex: 0xD8B597), Color(hex: 0xBD8A6C)],
                artwork: [Color(hex: 0xD4A983), Color(hex: 0x855941)],
                recordLabel: [Color(hex: 0xF0D2A9), Color(hex: 0xC88E64), Color(hex: 0x8A573C)]
            )
        }
    }
}

struct ThemePalette {
    let canvas: Color
    let sidebar: Color
    let inspector: Color
    let player: Color
    let line: Color
    let text: Color
    let muted: Color
    let accent: Color
    let accentDark: Color
    let selected: Color
    let onAccent: Color
    let recordInk: Color
    let hero: [Color]
    let artwork: [Color]
    let recordLabel: [Color]
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemeOption.morning.palette
}

extension EnvironmentValues {
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
