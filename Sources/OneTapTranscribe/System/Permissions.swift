import AVFoundation
import AppKit
import ApplicationServices

/// Thin helpers around the two TCC permissions this app needs:
/// Microphone (to record) and Accessibility (global hotkey + synthesized paste).
enum Permissions {

    // MARK: Microphone

    static func microphoneAuthorized() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    @discardableResult
    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    // MARK: Accessibility

    /// Whether the process is trusted for Accessibility. Pass `prompt: true`
    /// to surface the system "grant access" dialog if it isn't.
    @discardableResult
    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private static func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
