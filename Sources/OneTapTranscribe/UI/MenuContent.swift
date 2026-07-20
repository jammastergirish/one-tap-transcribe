import SwiftUI
import AppKit

/// The dropdown shown from the menu-bar icon (rendered as a native menu).
struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(state.status.menuLabel)

        Text("Hold \(store.settings.triggerKey.displayName) to talk")

        if !state.micAuthorized {
            Button("⚠︎ Grant Microphone access…") { state.requestPermissions() }
        }
        if !state.accessibilityTrusted {
            Button("⚠︎ Grant Accessibility access…") { state.requestPermissions() }
        }

        Divider()

        if !state.lastTranscript.isEmpty {
            Text("Last: \(preview(state.lastTranscript))")
            Button("Copy last transcript") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.lastTranscript, forType: .string)
            }
        }

        Divider()

        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("Re-check permissions") { state.refreshPermissions() }

        Divider()

        Button("Quit OneTap Transcribe") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func preview(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        return flat.count > 60 ? String(flat.prefix(60)) + "…" : flat
    }
}
