import SwiftUI
import AppKit

@main
struct OneTapTranscribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: SettingsStore
    @StateObject private var state: AppState

    init() {
        let store = SettingsStore()
        _store = StateObject(wrappedValue: store)
        _state = StateObject(wrappedValue: AppState(store: store))
    }

    var body: some Scene {
        Window("One Tap Transcribe", id: "home") {
            HomeView()
                .environmentObject(state)
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuPanel()
                .environmentObject(state)
                .environmentObject(store)
        } label: {
            Image(nsImage: AppArtwork.menuBarIcon())
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(state)
                .environmentObject(store)
                .frame(width: 580, height: 640)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppArtwork.appIcon()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSApp.activate(ignoringOtherApps: true) }
        return true
    }
}
