import AppKit
import SwiftUI

enum HUDPhase: Equatable { case hidden, recording, transcribing, inserting }

/// Shared state for the floating overlay: current phase + a rolling window of
/// recent audio levels for the waveform.
@MainActor
final class HUDModel: ObservableObject {
    static let barCount = 44

    @Published var phase: HUDPhase = .hidden
    @Published private(set) var levels: [Float] = Array(repeating: 0, count: HUDModel.barCount)

    func reset() {
        levels = Array(repeating: 0, count: Self.barCount)
    }

    func push(_ level: Float) {
        var next = levels
        next.removeFirst()
        next.append(level)
        levels = next
    }
}

/// Owns the borderless, click-through, non-activating panel that hosts the HUD.
/// Being non-activating is essential: the panel must never take keyboard focus,
/// or the synthesized ⌘V would paste into the wrong place.
@MainActor
final class OverlayController {
    let model = HUDModel()
    private var panel: NSPanel?
    private let size = NSSize(width: 260, height: 60)

    func show() {
        ensurePanel()
        position()
        panel?.alphaValue = 1
        panel?.orderFrontRegardless()   // show without stealing focus
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.panel?.orderOut(nil)
            self.model.phase = .hidden
            self.model.reset()
        })
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false

        let host = NSHostingView(rootView: HUDView().environmentObject(model))
        host.frame = NSRect(origin: .zero, size: size)
        p.contentView = host
        panel = p
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.minY + 130
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
