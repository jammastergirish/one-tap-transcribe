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

        var badge: String {
            switch self {
            case .idle:         return "Ready"
            case .preparing:    return "Loading"
            case .recording:    return "Listening"
            case .transcribing: return "Transcribing"
            case .cleaning:     return "Cleaning"
            case .inserting:    return "Inserting"
            case .error:        return "Error"
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var lastTranscriptAt: Date?
    /// Non-nil when the selected cleanup engine can't run (server down, Apple
    /// Intelligence off, …). Surfaced in the main window and menu.
    @Published private(set) var cleanupWarning: String?
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
    private var liveSession: LiveTranscriptionSession?
    private var partialTimer: Timer?

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
        applyAppearance(s.appearance)
        observeSettings()
        refreshPermissions()
        startPermissionWatch()
        prewarm()
        refreshCleanupAvailability()
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

    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Probe the selected cleanup engine so the UI can warn *before* dictation
    /// if it can't run (server down, Apple Intelligence off, …).
    func refreshCleanupAvailability() {
        let engine = cleaner
        let kind = store.settings.cleanup
        Task {
            guard kind != .none else { cleanupWarning = nil; return }
            cleanupWarning = await engine.availability().reason
        }
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
            startStreamingIfPossible()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func stopAndProcess() {
        guard status == .recording else { return }
        let samples = recorder.stop()
        recorder.onChunk16k = nil
        stopPartialPoll()
        if store.settings.playFeedbackSounds { SoundFeedback.stopCue() }

        if let session = liveSession {
            // Streaming: most audio is already transcribed; just finish the tail.
            liveSession = nil
            isBusy = true
            status = .transcribing
            setOverlayPhase(.transcribing)
            Task {
                defer { isBusy = false }
                let raw = await session.finish()
                await finishPipeline(raw)
            }
        } else {
            // Batch fallback (e.g. Apple engine, or streaming disabled/failed).
            let clip = AudioClip(samples: samples, sampleRate: recorder.sampleRate)
            guard !clip.isEffectivelySilent else { status = .idle; hideOverlay(); return }
            isBusy = true
            Task { await process(clip) }
        }
    }

    private func process(_ clip: AudioClip) async {
        defer { isBusy = false }
        do {
            status = .transcribing
            setOverlayPhase(.transcribing)
            let raw = try await transcriber.transcribe(clip)
            await finishPipeline(raw)
        } catch {
            status = .error(error.localizedDescription)
            hideOverlay()
        }
    }

    /// Cleanup + insert, shared by the streaming and batch paths.
    private func finishPipeline(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { status = .idle; hideOverlay(); return }

        var finalText = trimmed
        if store.settings.cleanup != .none {
            status = .cleaning
            setOverlayPhase(.cleaning)
            do {
                finalText = try await cleaner.clean(
                    trimmed,
                    systemPrompt: store.settings.cleanupSystemPrompt,
                    userTemplate: store.settings.cleanupUserTemplate
                )
                cleanupWarning = nil
            } catch {
                // Never drop the transcript: insert it raw and say why.
                finalText = trimmed
                cleanupWarning = await cleaner.availability().reason
                    ?? "Cleanup was skipped — raw text inserted."
            }
        }

        lastTranscript = finalText
        lastTranscriptAt = Date()
        guard !finalText.isEmpty else { status = .idle; hideOverlay(); return }

        status = .inserting
        TextInjector.insert(finalText, viaPaste: store.settings.pasteInsteadOfType)
        status = .idle
        hideOverlay()
    }

    // MARK: - Streaming

    private func startStreamingIfPossible() {
        guard store.settings.streaming, let capable = transcriber as? StreamingCapable else { return }
        Task {
            do {
                let session = try await capable.startStreamingSession()
                // The user may have released the key during session setup.
                guard status == .recording else { _ = await session.finish(); return }
                liveSession = session
                recorder.onChunk16k = { chunk in session.append(chunk) }
                startPartialPoll(session)
            } catch {
                // Streaming unavailable — the recorder is still accumulating for
                // the batch fallback in stopAndProcess.
            }
        }
    }

    private func startPartialPoll(_ session: LiveTranscriptionSession) {
        stopPartialPoll()
        guard store.settings.showOverlay, store.settings.showLiveText else { return }
        // Poll once per ~half second: slow enough to read calmly, since the
        // session already suppresses the per-token churn.
        partialTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.status == .recording else { return }
                let parts = await session.partialParts()
                self.overlay.model.confirmedText = parts.confirmed
                self.overlay.model.volatileText = parts.volatile
            }
        }
    }

    private func stopPartialPoll() {
        partialTimer?.invalidate()
        partialTimer = nil
    }

    // MARK: - Overlay helpers

    private func showOverlayRecording() {
        guard store.settings.showOverlay else { return }
        overlay.model.reset()
        overlay.model.triggerHint = store.settings.triggerKey.chip
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
                if i == 12 { overlay.model.confirmedText = "this is a live preview" }
                if i == 26 {
                    overlay.model.confirmedText = "this is a live preview of the transcript"
                    overlay.model.volatileText = "as you speak"
                }
                try? await Task.sleep(nanoseconds: 55_000_000)
            }
            overlay.model.phase = .transcribing
            try? await Task.sleep(nanoseconds: 800_000_000)
            overlay.model.phase = .cleaning
            try? await Task.sleep(nanoseconds: 800_000_000)
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

        applyAppearance(s.appearance)

        let newCleanup = Self.cleanupSignature(s)
        if newCleanup != cleanupSignature {
            cleanupSignature = newCleanup
            cleaner = CleanupEngineFactory.make(s)
            refreshCleanupAvailability()
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
