import SwiftUI

/// The main window — a compact status panel so the app is easy to find even
/// when the menu-bar icon is hidden (e.g. behind the notch).
struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: state.status.symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OneTap Transcribe").font(.headline)
                    Text(state.status.menuLabel)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            GroupBox {
                HStack {
                    Image(systemName: "keyboard")
                    Text("Hold ") + Text(store.settings.triggerKey.displayName).bold() + Text(" to talk, then release.")
                    Spacer()
                }
                .padding(4)
            }

            // Permission status
            VStack(alignment: .leading, spacing: 8) {
                permissionRow("Microphone", granted: state.micAuthorized)
                permissionRow("Accessibility", granted: state.accessibilityTrusted)
                if !state.micAuthorized || !state.accessibilityTrusted {
                    Button("Grant permissions…") { state.requestPermissions() }
                        .controlSize(.large)
                }
            }

            if !state.lastTranscript.isEmpty {
                GroupBox("Last transcript") {
                    ScrollView {
                        Text(state.lastTranscript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 90)
                    .padding(4)
                }
            }

            Spacer()

            HStack {
                Button("Settings…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Re-check permissions") { state.refreshPermissions() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 360)
    }

    @ViewBuilder
    private func permissionRow(_ title: String, granted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
            Spacer()
            Text(granted ? "Granted" : "Needed")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
