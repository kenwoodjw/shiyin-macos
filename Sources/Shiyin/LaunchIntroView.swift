import AVFoundation
import SwiftUI

struct LaunchIntroView: View {
    @Environment(\.themePalette) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("playLaunchSound") private var playLaunchSound = true
    @Binding var isPresented: Bool

    @State private var chime = LaunchChime()
    @State private var hasAppeared = false
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            theme.canvas

            Circle()
                .fill(RadialGradient(colors: [theme.accent.opacity(0.20), .clear],
                                     center: .center, startRadius: 40, endRadius: 330))
                .frame(width: 660, height: 660)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer()

                introRecord
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(hasAppeared ? 1 : 0.82)
                    .opacity(hasAppeared ? 1 : 0)
                    .accessibilityHidden(true)

                Text("拾音")
                    .font(.system(size: 45, weight: .semibold, design: .serif))
                    .tracking(8)
                    .foregroundStyle(theme.text)
                    .padding(.top, 34)

                Text("把喜欢的声音留在身边")
                    .font(.system(size: 14))
                    .tracking(2)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 12)

                Capsule()
                    .fill(theme.accent)
                    .frame(width: hasAppeared ? 74 : 12, height: 3)
                    .padding(.top, 32)

                Spacer()

                HStack {
                    Button {
                        playLaunchSound.toggle()
                        if playLaunchSound { chime.play() } else { chime.stop() }
                    } label: {
                        Label("启动音效", systemImage: playLaunchSound ? "speaker.wave.2" : "speaker.slash")
                    }
                    .help(playLaunchSound ? "关闭启动音效" : "开启启动音效")

                    Spacer()

                    Button("跳过") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 32)
                .padding(.bottom, 25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .task { await runIntro() }
        .onDisappear { chime.stop() }
    }

    private var introRecord: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.24), .black, Color(white: 0.14)],
                                     center: .center, startRadius: 12, endRadius: 108))
            ForEach(0..<9, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(index.isMultiple(of: 2) ? 0.10 : 0.055), lineWidth: 1)
                    .padding(CGFloat(index) * 8 + 12)
            }
            Circle()
                .fill(RadialGradient(colors: theme.recordLabel,
                                     center: .topLeading, startRadius: 4, endRadius: 65))
                .frame(width: 94, height: 94)
            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(theme.recordInk)
            Circle()
                .fill(theme.recordInk)
                .frame(width: 5, height: 5)
                .offset(y: 35)
        }
        .frame(width: 220, height: 220)
        .shadow(color: theme.accentDark.opacity(0.18), radius: 24, x: 0, y: 15)
    }

    @MainActor private func runIntro() async {
        if playLaunchSound { chime.play() }
        withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.65)) {
            hasAppeared = true
        }
        if !reduceMotion {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        try? await Task.sleep(for: .seconds(reduceMotion ? 0.8 : 2.4))
        guard !Task.isCancelled else { return }
        dismiss()
    }

    @MainActor private func dismiss() {
        chime.stop()
        withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.35)) {
            isPresented = false
        }
    }
}

@MainActor private final class LaunchChime {
    private var player: AVAudioPlayer?

    func play() {
        stop()
        guard let audio = Self.makeAudio() else { return }
        player = try? AVAudioPlayer(data: audio)
        player?.volume = 0.18
        player?.prepareToPlay()
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private static func makeAudio() -> Data? {
        let sampleRate = 44_100
        let duration = 1.15
        let sampleCount = Int(Double(sampleRate) * duration)
        let notes: [(start: Double, frequency: Double)] = [
            (0.05, 392.0), (0.23, 493.88), (0.42, 587.33)
        ]

        var pcm = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let value = notes.reduce(0.0) { sum, note in
                let age = time - note.start
                guard age >= 0, age < 0.55 else { return sum }
                let attack = min(1, age / 0.025)
                let release = pow(max(0, 1 - age / 0.55), 2)
                let wave = sin(2 * .pi * note.frequency * age)
                    + 0.18 * sin(2 * .pi * note.frequency * 2 * age)
                return sum + wave * attack * release * 0.28
            }
            var sample = Int16(max(-1, min(1, value)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }

        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        wav.appendLittleEndian(UInt32(36 + pcm.count))
        wav.append(contentsOf: "WAVEfmt ".utf8)
        wav.appendLittleEndian(UInt32(16))
        wav.appendLittleEndian(UInt16(1))
        wav.appendLittleEndian(UInt16(1))
        wav.appendLittleEndian(UInt32(sampleRate))
        wav.appendLittleEndian(UInt32(sampleRate * 2))
        wav.appendLittleEndian(UInt16(2))
        wav.appendLittleEndian(UInt16(16))
        wav.append(contentsOf: "data".utf8)
        wav.appendLittleEndian(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
