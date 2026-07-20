import SwiftUI
import AppKit

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

// MARK: - Status badge (READY)

struct StatusBadge: View {
    var text: String
    var color: Color = Theme.emberText
    var tint: Color = Theme.emberTint

    var body: some View {
        Text(text.uppercased())
            .font(.mono(10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint, in: RoundedRectangle(cornerRadius: 4))
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

// MARK: - Logo squircle

struct LogoSquircle: View {
    var side: CGFloat = 24
    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.23, style: .continuous)
            .fill(Theme.squircleBG)
            .frame(width: side, height: side)
            .overlay(
                WaveformGlyph(color: Theme.ember,
                              barWidth: side * 0.09,
                              spacing: side * 0.06,
                              height: side * 0.42)
            )
    }
}

// MARK: - Ember spinner

struct EmberSpinner: View {
    var size: CGFloat = 14
    @State private var angle: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(Theme.ember.opacity(0.35), lineWidth: 2)
            Circle().trim(from: 0, to: 0.3)
                .stroke(Theme.ember, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}

// MARK: - Ember checkbox toggle style

struct EmberCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isOn ? Theme.ember : Theme.checkboxOff)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.fieldBorder, lineWidth: configuration.isOn ? 0 : 1)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(configuration.isOn ? 1 : 0)
                    )
                    .offset(y: 2)
                configuration.label
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

// MARK: - Ghost/bordered button style ("Settings…", "Quit", "Preview")

struct GraphiteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.buttonBG, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.fieldBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Drawn artwork (app icon + menu-bar icon)

enum AppArtwork {
    /// Near-black squircle with centered ember waveform bars.
    static func appIcon(side: CGFloat = 512) -> NSImage {
        let img = NSImage(size: NSSize(width: side, height: side))
        img.lockFocus()
        let inset = side * 0.055
        let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
        NSColor(Theme.squircleBG).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.23, yRadius: rect.width * 0.23).fill()
        drawBars(in: rect, color: NSColor(Theme.ember),
                 maxFraction: 0.42, barWidthFraction: 0.10, gapFraction: 0.065)
        img.unlockFocus()
        return img
    }

    /// Monochrome template bars for the menu bar.
    static func menuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 15)
        let img = NSImage(size: size)
        img.lockFocus()
        drawBars(in: NSRect(origin: .zero, size: size), color: .black,
                 maxFraction: 0.82, barWidthFraction: 0.14, gapFraction: 0.09)
        img.unlockFocus()
        img.isTemplate = true
        return img
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
