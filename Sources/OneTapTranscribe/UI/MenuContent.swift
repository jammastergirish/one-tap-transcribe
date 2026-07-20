import SwiftUI
import AppKit

/// Custom menu-bar dropdown panel (MenuBarExtra `.window` style).
struct MenuPanel: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SettingsStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                LogoSquircle(side: 24)
                Text("One Tap Transcribe")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                StatusBadge(text: state.status.badge)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 7)

            Text("Hold \(store.settings.triggerKey.displayName) to talk, release to paste.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            Divider().overlay(Theme.divider)

            if !state.lastTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    MonoLabel(text: lastLabel, size: 10, tracking: 0.8, color: Theme.monoFaint)
                    Text(snippet)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider().overlay(Theme.divider)
            }

            if let warning = state.cleanupWarning {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10)).foregroundStyle(Theme.emberText)
                    Text("Cleanup: \(warning)")
                        .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider().overlay(Theme.divider)
            }

            VStack(spacing: 2) {
                MenuRow(title: "Open main window", systemImage: "macwindow") {
                    openWindow(id: "home")
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuRow(title: "Settings…", systemImage: "gearshape") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuRow(title: "Quit One Tap Transcribe", systemImage: "power") {
                    NSApp.terminate(nil)
                }
            }
            .padding(6)
        }
        .frame(width: 280)
        .background(Theme.windowBG)
        .onAppear { state.refreshCleanupAvailability() }
    }

    private var lastLabel: String {
        if let at = state.lastTranscriptAt {
            return "Last transcript · \(Self.timeFormatter.string(from: at))"
        }
        return "Last transcript"
    }

    private var snippet: String {
        let flat = state.lastTranscript.replacingOccurrences(of: "\n", with: " ")
        return flat.count > 44 ? String(flat.prefix(44)) + "…" : flat
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
}

private struct MenuRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(hover ? Theme.emberText : Theme.textSecondary)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(hover ? Theme.emberTint : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
