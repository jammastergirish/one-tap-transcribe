import SwiftUI
import GraphiteEmber
import AppKit

// One Tap Transcribe's own pieces. The shared theme and components come from
// the GraphiteEmber package.

// MARK: - Waveform glyph (logo + accents)

/// Vertical rounded ember bars, the app's signature mark.
struct WaveformGlyph: View {
    var relativeHeights: [CGFloat] = [0.45, 1.0, 0.68, 0.32]
    var color: Color = Theme.ember
    var barWidth: CGFloat = 3.5
    var spacing: CGFloat = 3
    var height: CGFloat = 18

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(relativeHeights.indices, id: \.self) { i in
                Capsule().fill(color)
                    .frame(width: barWidth, height: max(2, relativeHeights[i] * height))
            }
        }
        .frame(height: height)
    }
}

extension LogoSquircle where Mark == WaveformGlyph {
    /// The squircle with One Tap Transcribe's waveform mark.
    init(side: CGFloat = 24) {
        self.init(side: side) { side in
            WaveformGlyph(color: Theme.ember,
                          barWidth: side * 0.09,
                          spacing: side * 0.06,
                          height: side * 0.42)
        }
    }
}

// MARK: - Key-cap chip (R⌘)

struct KeyCapChip: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.mono(11, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).stroke(Theme.fieldBorder, lineWidth: 1))
    }
}

// MARK: - Mono field with ember focus ring

struct MonoTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(.mono(12))
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.fieldBG, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(focused ? Theme.ember : Theme.fieldBorder, lineWidth: focused ? 1.5 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.ember.opacity(0.16), lineWidth: 3)
                .padding(-1.5)
                .opacity(focused ? 1 : 0)
        )
        .focused($focused)
    }
}

// MARK: - Drawn artwork (app icon + menu-bar icon)

enum AppArtwork {
    /// Near-black squircle with centered ember waveform bars.
    static func appIcon() -> NSImage {
        SquircleIcon.image(mark: drawAppMark)
    }

    /// Handles the build script's `--write-iconset <folder>` launch flag.
    static func writeIconsetIfRequested() {
        SquircleIcon.writeIconsetIfRequested(mark: drawAppMark)
    }

    /// Monochrome template bars for the menu bar.
    static func menuBarIcon() -> NSImage {
        SquircleIcon.template(size: NSSize(width: 18, height: 15)) { rect in
            drawBars(in: rect, color: .black, maxFraction: 0.82, barWidthFraction: 0.14, gapFraction: 0.09)
        }
    }

    private static func drawAppMark(in rect: NSRect) {
        drawBars(in: rect, color: NSColor(Theme.ember),
                 maxFraction: 0.42, barWidthFraction: 0.10, gapFraction: 0.065)
    }

    private static func drawBars(in rect: NSRect, color: NSColor,
                                 maxFraction: CGFloat, barWidthFraction: CGFloat, gapFraction: CGFloat) {
        let rel: [CGFloat] = [0.45, 1.0, 0.68, 0.32]
        let barW = rect.width * barWidthFraction
        let gap = rect.width * gapFraction
        let totalW = CGFloat(rel.count) * barW + CGFloat(rel.count - 1) * gap
        var x = rect.midX - totalW / 2
        color.setFill()
        for h in rel {
            let barH = rect.height * maxFraction * h
            let bar = NSBezierPath(roundedRect: NSRect(x: x, y: rect.midY - barH / 2, width: barW, height: barH),
                                   xRadius: barW / 2, yRadius: barW / 2)
            bar.fill()
            x += barW + gap
        }
    }
}
