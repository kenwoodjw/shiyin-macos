import SwiftUI

struct ArtworkView: View {
    @Environment(\.themePalette) private var theme
    let title: String
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(6, size * 0.12))
                .fill(LinearGradient(colors: theme.artwork, startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(Color.black.opacity(0.12)).frame(width: size * 0.68)
            Circle().stroke(Color.white.opacity(0.26), lineWidth: 1).frame(width: size * 0.53)
            Circle().fill(theme.accentDark).frame(width: size * 0.16)
            Text(String(title.prefix(2)).uppercased())
                .font(.system(size: size * 0.15, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .offset(y: size * 0.30)
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

struct RecordView: View {
    @Environment(\.themePalette) private var theme
    var size: CGFloat = 232

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.black, Color(white: 0.12), .black], center: .center, startRadius: 0, endRadius: size / 2))
            ForEach(0..<8, id: \.self) { index in
                Circle().stroke(.white.opacity(index.isMultiple(of: 2) ? 0.10 : 0.055), lineWidth: 0.7)
                    .padding(CGFloat(index) * 9 + 7)
            }
            Circle().fill(RadialGradient(colors: theme.recordLabel, center: .topLeading, startRadius: 2, endRadius: size * 0.33))
                .frame(width: size * 0.42, height: size * 0.42)
            VStack(spacing: 6) {
                Text("PRIVATE\nPRESSING").multilineTextAlignment(.center)
                    .font(.system(size: size * 0.055, weight: .bold, design: .serif))
                Circle().fill(theme.recordInk).frame(width: 8, height: 8)
                Text("SIDE A · 33 RPM").font(.system(size: size * 0.033, weight: .medium))
            }
            .foregroundStyle(theme.recordInk)
        }
        .frame(width: size, height: size)
        .shadow(color: theme.accentDark.opacity(0.28), radius: 20, x: -8, y: 12)
    }
}

struct SoftButtonStyle: ButtonStyle {
    @Environment(\.themePalette) private var theme
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? theme.onAccent : theme.accentDark)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(filled ? theme.accent : theme.selected, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
