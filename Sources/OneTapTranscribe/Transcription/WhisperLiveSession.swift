import Foundation
import WhisperKit

/// Streaming transcription for WhisperKit using the confirmed-segment
/// sliding-window algorithm (the WhisperAX approach): each pass only re-decodes
/// the audio after the last confirmed segment (`clipTimestamps`), so on release
/// just a short tail remains.
///
/// We feed our OWN 16 kHz mono buffers in (via `append`), so the microphone tap
/// that also drives the waveform HUD stays ours. All `transcribe` calls are
/// serialized — WhisperKit is not an actor and must never decode concurrently.
actor WhisperLiveSession: LiveTranscriptionSession {
    private let whisper: WhisperKit
    private let language: String?

    // Tuning
    private let requiredForConfirmation = 2
    private let delayInterval: Float = 0.7   // seconds of new audio before a pass

    // Ordered input (yield is thread-safe; drained on the actor in order).
    private nonisolated let inputStream: AsyncStream<[Float]>
    private nonisolated let inputCont: AsyncStream<[Float]>.Continuation

    // Rolling state
    private var buffer: [Float] = []
    private var lastBufferSize = 0
    private var lastConfirmedEnd: Float = 0
    private var confirmed: [TranscriptionSegment] = []
    private var unconfirmed: [TranscriptionSegment] = []
    private var currentText = ""

    private var running = false
    private var loopTask: Task<Void, Never>?
    private var drainTask: Task<Void, Never>?

    init(whisper: WhisperKit, language: String?) {
        self.whisper = whisper
        self.language = language
        let (stream, cont) = AsyncStream<[Float]>.makeStream()
        self.inputStream = stream
        self.inputCont = cont
    }

    nonisolated func append(_ chunk16k: [Float]) {
        inputCont.yield(chunk16k)
    }

    func start() {
        guard !running else { return }
        running = true
        drainTask = Task { [weak self] in
            guard let self else { return }
            for await chunk in self.inputStream {
                await self.appendToBuffer(chunk)
            }
        }
        loopTask = Task { [weak self] in await self?.runLoop() }
    }

    func partialParts() -> (confirmed: String, volatile: String) {
        // Deliberately exclude `currentText` (the per-token in-flight decode):
        // it changes many times a second and reads as jank. Segments update
        // roughly once per pass, which is calm enough to display.
        let confirmedText = confirmed.map(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let volatileText = unconfirmed.map(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (confirmedText, volatileText)
    }

    func finish() async -> String {
        running = false
        inputCont.finish()
        await drainTask?.value    // ensure every fed chunk is in the buffer
        await loopTask?.value     // ensure the in-flight pass finished (no overlap)
        drainTask = nil
        loopTask = nil

        if let final = try? await runTranscribe(buffer) {
            confirm(final.segments)
        }
        confirmed.append(contentsOf: unconfirmed)
        unconfirmed = []
        return confirmed.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Internals

    private func appendToBuffer(_ chunk: [Float]) {
        buffer.append(contentsOf: chunk)
    }

    private func runLoop() async {
        while running {
            do { try await step() } catch { break }
        }
    }

    private func step() async throws {
        let snapshot = buffer
        let newSeconds = Float(snapshot.count - lastBufferSize) / Float(WhisperKit.sampleRate)
        guard newSeconds > delayInterval else {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return
        }
        lastBufferSize = snapshot.count
        if let result = try await runTranscribe(snapshot) {
            confirm(result.segments)
        }
    }

    private func runTranscribe(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard !samples.isEmpty else { return nil }
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: 2,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,     // needed for segment start/end
            wordTimestamps: false,
            clipTimestamps: [lastConfirmedEnd]
        )
        let callback: TranscriptionCallback = { [weak self] progress in
            guard let self else { return nil }
            Task { await self.setCurrentText(progress.text) }
            return nil
        }
        let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options, callback: callback)
        return TranscriptionUtilities.mergeTranscriptionResults(results)
    }

    private func setCurrentText(_ text: String) { currentText = text }

    private func confirm(_ segments: [TranscriptionSegment]) {
        currentText = ""
        if segments.count > requiredForConfirmation {
            let n = segments.count - requiredForConfirmation
            let newlyConfirmed = Array(segments.prefix(n))
            let remaining = Array(segments.suffix(requiredForConfirmation))
            if let last = newlyConfirmed.last, last.end > lastConfirmedEnd {
                lastConfirmedEnd = last.end
                for s in newlyConfirmed where !confirmed.contains(s) {
                    confirmed.append(s)
                }
            }
            unconfirmed = remaining
        } else {
            unconfirmed = segments
        }
    }
}
