import SwiftUI

/// The floating overlay pill. Fixed dark appearance in both OS modes.
struct HUDView: View {
    @EnvironmentObject var model: HUDModel

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.overlayBG, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.overlayBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: model.phase)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .recording:
            VStack(spacing: 7) {
                if model.hasLiveText {
                    LiveCaption(confirmed: model.confirmedText, volatile: model.volatileText)
                } else {
                    Text("Listening…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.overlayText)
                }
                WaveformBars(levels: model.levels, color: Theme.ember)
                    .frame(width: 150, height: 22)
            }
        case .transcribing:
            statusRow("Transcribing…")
        case .cleaning:
            statusRow("Cleaning up…")
        case .hidden:
            Color.clear.frame(width: 1, height: 1)
        }
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 9) {
            EmberSpinner(size: 14)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.overlayText)
        }
    }
}

/// Single-line live caption: confirmed text solid, settling tail dimmed.
struct LiveCaption: View {
    let confirmed: String
    let volatile: String

    var body: some View {
        let joiner = (!confirmed.isEmpty && !volatile.isEmpty) ? " " : ""
        (Text(confirmed).foregroundColor(Theme.overlayText)
         + Text(joiner + volatile).foregroundColor(Theme.overlayDim))
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.head)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380, alignment: .center)
    }
}

/// Centered bar waveform, mirrored from the vertical center.
struct WaveformBars: View {
    let levels: [Float]
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let count = max(1, levels.count)
            let spacing: CGFloat = 2
            let barWidth = max(1.5, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth,
                               height: max(3, CGFloat(levels[i]) * geo.size.height))
                        .animation(.easeOut(duration: 0.09), value: levels[i])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
