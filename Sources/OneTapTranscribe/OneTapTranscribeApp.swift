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
        // Main window — makes the app findable in the Dock / Cmd-Tab even when
        // the menu-bar icon is hidden behind the notch.
        Window("OneTap Transcribe", id: "home") {
            HomeView()
                .environmentObject(state)
                .environmentObject(store)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
                .environmentObject(store)
        } label: {
            Image(systemName: state.status.symbol)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(state)
                .environmentObject(store)
                .frame(width: 560, height: 620)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring the main window to the front on launch so it's immediately
        // visible. Activation policy (Dock icon vs. menu-bar-only) is applied
        // by AppState from the user's setting.
        NSApp.activate(ignoringOtherApps: true)
    }

    // Re-open the main window when the Dock icon is clicked.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSApp.activate(ignoringOtherApps: true) }
        return true
    }
}
