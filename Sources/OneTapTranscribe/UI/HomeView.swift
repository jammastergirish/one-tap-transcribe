import SwiftUI

/// Main window — "Graphite & Ember": mono titlebar, inverse hotkey banner,
/// ember-accented last-transcript card, footer.
struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SettingsStore
    @Environment(\.openSettings) private var openSettings

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
                HStack {
                    MonoLabel(text: "Last transcript", size: 11, tracking: 1.0, color: Theme.textSecondary)
                    Spacer()
                    if let meta = transcriptMeta {
                        Text(meta).font(.mono(11)).foregroundStyle(Theme.monoFaint)
                    }
                }
                transcriptCard
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

    private var transcriptCard: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Theme.ember).frame(width: 3)
            Group {
                if state.lastTranscript.isEmpty {
                    Text("No transcript yet. Hold your key and speak.")
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(state.lastTranscript)
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                }
            }
            .font(.system(size: 13.5))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(minHeight: 96, alignment: .topLeading)
        .background(Theme.cardBG, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.fieldBorder, lineWidth: 1))
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

    // MARK: Helpers

    private var transcriptMeta: String? {
        guard !state.lastTranscript.isEmpty else { return nil }
        let words = state.lastTranscript.split { $0 == " " || $0 == "\n" }.count
        let time = state.lastTranscriptAt.map { Self.timeFormatter.string(from: $0) }
        let wordStr = "\(words) word\(words == 1 ? "" : "s")"
        return time.map { "\($0) · \(wordStr)" } ?? wordStr
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
