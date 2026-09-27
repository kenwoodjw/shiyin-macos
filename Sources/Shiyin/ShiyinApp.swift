import AppKit
import SwiftUI

final class ShiyinAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main struct ShiyinApp: App {
    @NSApplicationDelegateAdaptor(ShiyinAppDelegate.self) private var appDelegate
    @State private var store = MusicStore()
    @State private var showsLaunchIntro = true
    @AppStorage("appearanceTheme") private var appearanceTheme = ThemeOption.morning.rawValue

    private var selectedTheme: ThemeOption { ThemeOption(rawValue: appearanceTheme) ?? .morning }

    var body: some Scene {
        WindowGroup("拾音", id: "main") {
            ZStack {
                ContentView(store: store)
                    .allowsHitTesting(!showsLaunchIntro)
                    .accessibilityHidden(showsLaunchIntro)
                if showsLaunchIntro {
                    LaunchIntroView(isPresented: $showsLaunchIntro)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(minWidth: 990, minHeight: 660)
            .environment(\.themePalette, selectedTheme.palette)
            .preferredColorScheme(selectedTheme.isDark ? .dark : .light)
            .onAppear {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                store.enableSystemPlayback()
            }
        }
        .defaultSize(width: 1280, height: 810)
        .commands {
            CommandGroup(after: .newItem) {
                Button("导入音频链接") { store.isImportPresented = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("播放") {
                Button(store.isPlaying ? "暂停" : "播放") { store.togglePlay() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("下一首") { store.next() }
                Button("上一首") { store.previous() }
            }
        }
        MenuBarExtra("拾音", systemImage: "music.note") {
            MenuBarPlayerView(store: store)
                .environment(\.themePalette, selectedTheme.palette)
                .preferredColorScheme(selectedTheme.isDark ? .dark : .light)
        }
        .menuBarExtraStyle(.window)
    }
}
