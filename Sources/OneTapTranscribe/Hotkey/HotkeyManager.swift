import AppKit

/// Press-and-hold push-to-talk on a single modifier key.
///
/// We watch `.flagsChanged` events globally and gate on the physical key's
/// `keyCode` (so, e.g., only the *right* Command triggers, not the left one)
/// plus whether its modifier flag is currently set (press vs. release).
///
/// Global event monitoring requires Accessibility permission — see
/// `Permissions.ensureAccessibility()`.
@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var triggerKey: TriggerKey
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isDown = false

    init(triggerKey: TriggerKey) {
        self.triggerKey = triggerKey
    }

    func updateTrigger(_ key: TriggerKey) {
        guard key != triggerKey else { return }
        triggerKey = key
        isDown = false
    }

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
        // Also catch the key while one of our own windows (Settings) is key.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
        isDown = false
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == triggerKey.keyCode else { return }
        let pressed = event.modifierFlags.contains(triggerKey.modifierFlag)
        if pressed && !isDown {
            isDown = true
            onPress?()
        } else if !pressed && isDown {
            isDown = false
            onRelease?()
        }
    }
}

extension TriggerKey {
    /// Physical key codes (right-hand modifiers where applicable).
    var keyCode: UInt16 {
        switch self {
        case .fn:           return 63   // globe / fn
        case .rightCommand: return 54
        case .rightOption:  return 61
        case .rightControl: return 62
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .fn:           return .function
        case .rightCommand: return .command
        case .rightOption:  return .option
        case .rightControl: return .control
        }
    }
}
