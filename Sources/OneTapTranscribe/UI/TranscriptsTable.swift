import SwiftUI
import AppKit

/// Recent transcripts, newest first. Click a row to copy it; right-click to
/// copy or delete.
struct TranscriptsTable: View {
    @EnvironmentObject var state: AppState
    var maxRowsWithoutScroll = 6
    var scrollHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            if state.history.isEmpty {
                Text("No transcripts yet. Hold your key and speak.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
            } else if state.history.count <= maxRowsWithoutScroll {
                rows
            } else {
                ScrollView { rows }.frame(height: scrollHeight)
            }
        }
        .background(Theme.cardBG, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.fieldBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var rows: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(state.history.enumerated()), id: \.element.id) { i, entry in
                TranscriptRow(entry: entry)
                if i < state.history.count - 1 {
                    Divider().overlay(Theme.divider)
                }
            }
        }
    }
}

private struct TranscriptRow: View {
    @EnvironmentObject var state: AppState
    let entry: TranscriptEntry
    @State private var hover = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.when(entry.date))
                    .font(.mono(11))
                    .foregroundStyle(Theme.monoFaint)
                if copied {
                    Text("Copied").font(.mono(10, weight: .semibold)).foregroundStyle(Theme.successText)
                } else {
                    Text("\(entry.wordCount) word\(entry.wordCount == 1 ? "" : "s")")
                        .font(.mono(10))
                        .foregroundStyle(Theme.monoFaint.opacity(0.8))
                }
            }
            .frame(width: 92, alignment: .leading)

            Text(entry.text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(Theme.emberText)
                .opacity(hover && !copied ? 1 : 0)
                .frame(width: 14, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(hover ? Theme.emberTint : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { copy() }
        .help("Click to copy")
        .contextMenu {
            Button("Copy") { copy() }
            Divider()
            Button("Delete") { state.deleteTranscript(entry) }
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    // "Today 19:53", "Yesterday 08:12", "Mon 9 Nov 14:03", "9 Nov 2025"
    static func when(_ date: Date) -> String {
        let cal = Calendar.current
        let time = timeFmt.string(from: date)
        if cal.isDateInToday(date) { return "Today \(time)" }
        if cal.isDateInYesterday(date) { return "Yest. \(time)" }
        if cal.isDate(date, equalTo: Date(), toGranularity: .year) { return "\(dayFmt.string(from: date)) \(time)" }
        return yearFmt.string(from: date)
    }

    private static let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d MMM"; return f }()
    private static let yearFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f }()
}
