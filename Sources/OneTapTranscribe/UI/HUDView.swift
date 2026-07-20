import SwiftUI

/// The pill shown in the floating overlay. Switches between a live waveform
/// (recording) and status text (transcribing / inserting).
struct HUDView: View {
    @EnvironmentObject var model: HUDModel

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.10)))
            .shadow(color: .black.opacity(0.30), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: model.phase)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .recording:
            WaveformBars(levels: model.levels)
                .frame(width: 170, height: 26)
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Transcribing…").font(.system(size: 13, weight: .medium))
            }
        case .inserting:
            HStack(spacing: 8) {
                Image(systemName: "text.cursor")
                Text("Inserting…").font(.system(size: 13, weight: .medium))
            }
        case .hidden:
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

/// A centered bar waveform. Bars grow from the vertical center, mirrored, so it
/// reads like an audio meter.
struct WaveformBars: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geo in
            let count = max(1, levels.count)
            let spacing: CGFloat = 2
            let barWidth = max(1.5, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: barWidth,
                               height: max(3, CGFloat(levels[i]) * geo.size.height))
                        .animation(.easeOut(duration: 0.09), value: levels[i])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
