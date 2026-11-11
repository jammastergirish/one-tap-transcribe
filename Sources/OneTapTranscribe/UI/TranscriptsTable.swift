import SwiftUI
import GraphiteEmber
import AppKit

/// Recent transcripts, newest first. Click a row to copy it; right-click to
/// copy or delete.
struct TranscriptsTable: View {
    @EnvironmentObject var state: AppState
    var maxRowsWithoutScroll = 6
    var scrollHeight: CGFloat = 300

    var body: some View {
        TableCard(state.history,
                  emptyMessage: "No transcripts yet. Hold your key and speak.",
                  maxRowsWithoutScroll: maxRowsWithoutScroll,
                  scrollHeight: scrollHeight) { entry in
            TranscriptRow(entry: entry)
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
                Text(Format.when(entry.date))
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
            .frame(width: 110, alignment: .leading)

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
        .tableRowHover($hover)
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
}
