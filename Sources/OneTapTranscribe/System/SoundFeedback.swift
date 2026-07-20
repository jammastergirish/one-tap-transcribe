import AppKit

/// Subtle audible cues for start/stop of recording.
enum SoundFeedback {
    static func startCue() { NSSound(named: "Tink")?.play() }
    static func stopCue()  { NSSound(named: "Pop")?.play() }
}
