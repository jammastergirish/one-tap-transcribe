import Foundation
import Speech
import AVFoundation

/// Apple's built-in on-device speech-to-text (`SpeechAnalyzer` /
/// `SpeechTranscriber`, new in macOS 26). No third-party dependency; the
/// per-locale model is downloaded once via `AssetInventory`.
///
/// We run in batch: the whole recorded clip is fed as one input, then we
/// finalize and collect the final results.
final class AppleSpeechEngine: TranscriptionEngine {
    let displayName = "Apple SpeechTranscriber"

    private let locale: Locale

    init(localeIdentifier: String) {
        self.locale = Locale(identifier: localeIdentifier)
    }

    func prepare(progress: (@Sendable (Double) -> Void)?) async throws {
        let transcriber = makeTranscriber()
        try await ensureModelInstalled(for: transcriber)
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        let transcriber = makeTranscriber()
        try await ensureModelInstalled(for: transcriber)

        let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.noCompatibleAudioFormat
        }

        // Wrap our 16 kHz mono clip and convert to the analyzer's format.
        let srcFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: clip.sampleRate,
            channels: 1,
            interleaved: false
        )!
        let srcBuffer = Self.makeBuffer(clip.samples, format: srcFormat)
        let converted = try BufferConverter().convert(srcBuffer, to: analyzerFormat)

        // Collect final results as they stream out.
        let collector = Task { () -> String in
            var acc = AttributedString("")
            for try await result in transcriber.results where result.isFinal {
                acc += result.text
            }
            return String(acc.characters)
        }

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: stream)
        continuation.yield(AnalyzerInput(buffer: converted))
        continuation.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()

        let text = try await collector.value
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func makeTranscriber() -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
    }

    private func ensureModelInstalled(for transcriber: SpeechTranscriber) async throws {
        let want = locale.identifier(.bcp47)

        let supported = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
        guard supported.contains(want) else {
            throw TranscriptionError.localeUnsupported(locale.identifier)
        }

        let installed = await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }
        if !installed.contains(want) {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }
    }

    private static func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer {
        let capacity = AVAudioFrameCount(max(1, samples.count))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                if let base = src.baseAddress {
                    channel[0].update(from: base, count: samples.count)
                }
            }
        }
        return buffer
    }
}
