import SwiftUI
import AppKit
import Combine

/// Central coordinator: owns the hotkey, recorder, and the currently-selected
/// transcription + cleanup engines, and drives the
/// record → transcribe → clean → insert pipeline.
@MainActor
final class AppState: ObservableObject {
    enum Status: Equatable {
        case idle
        case preparing(String)
        case recording
        case transcribing
        case cleaning
        case inserting
        case error(String)

        var menuLabel: String {
            switch self {
            case .idle:              return "Ready"
            case .preparing(let s):  return s
            case .recording:         return "Recording…"
            case .transcribing:      return "Transcribing…"
            case .cleaning:          return "Cleaning up…"
            case .inserting:         return "Inserting…"
            case .error(let e):      return "Error: \(e)"
            }
        }

        var symbol: String {
            switch self {
            case .idle:         return "mic"
            case .preparing:    return "arrow.down.circle"
            case .recording:    return "mic.fill"
            case .transcribing: return "waveform"
            case .cleaning:     return "sparkles"
            case .inserting:    return "text.cursor"
            case .error:        return "exclamationmark.triangle"
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var micAuthorized = false
    @Published private(set) var accessibilityTrusted = false

    let store: SettingsStore
    let overlay = OverlayController()

    private let recorder = AudioRecorder()
    private let hotkey: HotkeyManager
    private var transcriber: TranscriptionEngine
    private var cleaner: CleanupEngine

    private var sttSignature: String
    private var cleanupSignature: String
    private var isBusy = false
    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?

    init(store: SettingsStore) {
        self.store = store
        let s = store.settings
        self.hotkey = HotkeyManager(triggerKey: s.triggerKey)
        self.transcriber = TranscriptionEngineFactory.make(s)
        self.cleaner = CleanupEngineFactory.make(s)
        self.sttSignature = Self.sttSignature(s)
        self.cleanupSignature = Self.cleanupSignature(s)

        hotkey.onPress = { [weak self] in self?.startRecording() }
        hotkey.onRelease = { [weak self] in self?.stopAndProcess() }
        hotkey.start()

        recorder.onLevel = { [weak self] level in
            guard let self, self.overlay.model.phase == .recording else { return }
            self.overlay.model.push(level)
        }

        applyActivationPolicy(s.menuBarOnly)
        observeSettings()
        refreshPermissions()
        startPermissionWatch()
        prewarm()
    }

    /// Polls TCC so the UI updates the moment the user flips a permission in
    /// System Settings — and, when Accessibility is newly granted, re-arms the
    /// global hotkey so it starts working without an app relaunch.
    private func startPermissionWatch() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollPermissions() }
        }
    }

    private func pollPermissions() {
        let mic = Permissions.microphoneAuthorized()
        let ax = Permissions.accessibilityTrusted(prompt: false)
        if ax && !accessibilityTrusted {
            hotkey.stop()
            hotkey.start()   // re-arm now that we're trusted
            if store.settings.playFeedbackSounds { SoundFeedback.startCue() }
        }
        if mic != micAuthorized { micAuthorized = mic }
        if ax != accessibilityTrusted { accessibilityTrusted = ax }
    }

    private func applyActivationPolicy(_ menuBarOnly: Bool) {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
    }

    // MARK: - Recording pipeline

    private func startRecording() {
        guard !isBusy, status == .idle || isErrorStatus else { return }
        guard micAuthorized else { requestPermissions(); return }
        do {
            try recorder.start()
            status = .recording
            showOverlayRecording()
            if store.settings.playFeedbackSounds { SoundFeedback.startCue() }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func stopAndProcess() {
        guard status == .recording else { return }
        let samples = recorder.stop()
        if store.settings.playFeedbackSounds { SoundFeedback.stopCue() }

        let clip = AudioClip(samples: samples, sampleRate: recorder.sampleRate)
        guard !clip.isEffectivelySilent else { status = .idle; hideOverlay(); return }

        isBusy = true
        Task { await process(clip) }
    }

    private func process(_ clip: AudioClip) async {
        defer { isBusy = false }
        do {
            status = .transcribing
            setOverlayPhase(.transcribing)
            let raw = try await transcriber.transcribe(clip)
            guard !raw.isEmpty else { status = .idle; hideOverlay(); return }

            var finalText = raw
            if store.settings.cleanup != .none {
                status = .cleaning
                finalText = (try? await cleaner.clean(
                    raw,
                    systemPrompt: store.settings.cleanupSystemPrompt,
                    userTemplate: store.settings.cleanupUserTemplate
                )) ?? raw
            }

            lastTranscript = finalText
            guard !finalText.isEmpty else { status = .idle; hideOverlay(); return }

            status = .inserting
            setOverlayPhase(.inserting)
            TextInjector.insert(finalText, viaPaste: store.settings.pasteInsteadOfType)
            status = .idle
            hideOverlay()
        } catch {
            status = .error(error.localizedDescription)
            hideOverlay()
        }
    }

    // MARK: - Overlay helpers

    private func showOverlayRecording() {
        guard store.settings.showOverlay else { return }
        overlay.model.reset()
        overlay.model.phase = .recording
        overlay.show()
    }

    private func setOverlayPhase(_ phase: HUDPhase) {
        guard store.settings.showOverlay, overlay.model.phase != .hidden else { return }
        overlay.model.phase = phase
    }

    private func hideOverlay() {
        overlay.hide()
    }

    /// Shows the overlay with a synthetic waveform, then a brief "Transcribing…",
    /// so it can be previewed from Settings without recording.
    func previewOverlay() {
        overlay.model.reset()
        overlay.model.phase = .recording
        overlay.show()
        Task { @MainActor in
            for i in 0..<45 {
                let t = Double(i) / 5.0
                overlay.model.push(Float(0.25 + 0.55 * abs(sin(t)) + 0.15 * abs(sin(t * 2.7))))
                try? await Task.sleep(nanoseconds: 55_000_000)
            }
            overlay.model.phase = .transcribing
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            overlay.hide()
        }
    }

    private var isErrorStatus: Bool { if case .error = status { return true }; return false }

    /// Load the transcription model ahead of first use so the first dictation
    /// isn't blocked on a download / model load.
    func prewarm() {
        guard !isBusy else { return }
        let engineName = transcriber.displayName
        Task {
            status = .preparing("Preparing \(engineName)…")
            do {
                try await transcriber.prepare(progress: nil)
                if case .preparing = status { status = .idle }
            } catch {
                status = .error("Model prep failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Settings observation

    private func observeSettings() {
        store.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] newSettings in
                self?.applySettings(newSettings)
            }
            .store(in: &cancellables)
    }

    private func applySettings(_ s: AppSettings) {
        hotkey.updateTrigger(s.triggerKey)
        applyActivationPolicy(s.menuBarOnly)

        let newSTT = Self.sttSignature(s)
        if newSTT != sttSignature {
            sttSignature = newSTT
            transcriber = TranscriptionEngineFactory.make(s)
            prewarm()
        }

        let newCleanup = Self.cleanupSignature(s)
        if newCleanup != cleanupSignature {
            cleanupSignature = newCleanup
            cleaner = CleanupEngineFactory.make(s)
        }
    }

    private static func sttSignature(_ s: AppSettings) -> String {
        "\(s.sttEngine.rawValue)|\(s.whisperModel.rawValue)|\(s.whisperLanguage)|\(s.appleSpeechLocale)"
    }

    private static func cleanupSignature(_ s: AppSettings) -> String {
        "\(s.cleanup.rawValue)|\(s.ollamaEndpoint)|\(s.ollamaModel)|\(s.openAIEndpoint)|\(s.openAIModel)|\(s.openAIAPIKey)"
    }

    // MARK: - Permissions

    func refreshPermissions() {
        micAuthorized = Permissions.microphoneAuthorized()
        accessibilityTrusted = Permissions.accessibilityTrusted(prompt: false)
    }

    func requestPermissions() {
        Task {
            micAuthorized = await Permissions.requestMicrophone()
            // Prompts the system dialog if not yet trusted.
            accessibilityTrusted = Permissions.accessibilityTrusted(prompt: true)
        }
    }
}
