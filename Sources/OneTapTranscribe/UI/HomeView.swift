import SwiftUI

/// Main window — "Graphite & Ember": mono titlebar, inverse hotkey banner,
/// ember-accented last-transcript card, footer.
struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SettingsStore
    @Environment(\.openSettings) private var openSettings
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            titlebar
            Divider().overlay(Theme.divider)
            content
        }
        .frame(width: 400)
        .background(Theme.windowBG)
    }

    // MARK: Titlebar

    private var titlebar: some View {
        HStack(spacing: 10) {
            MonoLabel(text: "One Tap Transcribe", size: 12, tracking: 0.8, color: Theme.textPrimary)
            Spacer()
            StatusBadge(text: state.status.badge)
        }
        .padding(.horizontal, 20)   // aligned with the content below
        .padding(.top, 30)          // sits just below the traffic lights
        .padding(.bottom, 12)
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            hotkeyBanner

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    MonoLabel(text: "Recent transcripts", size: 11, tracking: 1.0, color: Theme.textSecondary)
                    Spacer()
                    if !state.history.isEmpty {
                        Text("\(state.history.count)").font(.mono(11)).foregroundStyle(Theme.monoFaint)
                        Button("Clear") { confirmClear = true }
                            .buttonStyle(.plain)
                            .font(.mono(11, weight: .medium))
                            .foregroundStyle(Theme.emberText)
                    }
                }
                TranscriptsTable()
            }
            .confirmationDialog("Delete all saved transcripts?", isPresented: $confirmClear) {
                Button("Delete All", role: .destructive) { state.clearHistory() }
            } message: {
                Text("This removes the transcript history from this Mac. It can't be undone.")
            }

            if let warning = state.cleanupWarning {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(Theme.emberText)
                    Text("Cleanup unavailable — \(warning) Transcripts are inserted uncleaned.")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.emberTint, in: RoundedRectangle(cornerRadius: 8))
            }

            footer
        }
        .padding(20)
        .onAppear { state.refreshCleanupAvailability() }
    }

    private var hotkeyBanner: some View {
        HStack(spacing: 12) {
            WaveformGlyph(color: Theme.ember, barWidth: 3, spacing: 2.5, height: 18)
            (Text("Hold ").foregroundColor(Theme.inverseText)
             + Text(store.settings.triggerKey.displayName).foregroundColor(.white).bold()
             + Text(" to talk, then release.").foregroundColor(Theme.inverseText))
                .font(.system(size: 13))
            Spacer(minLength: 8)
            KeyCapChip(text: store.settings.triggerKey.chip)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Theme.inversePanelBG, in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            Button("Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(GraphiteButtonStyle())
    }
}
