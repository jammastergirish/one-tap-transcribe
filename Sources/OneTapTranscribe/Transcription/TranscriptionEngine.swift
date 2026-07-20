import Foundation

/// A mono audio clip handed to a transcription engine.
struct AudioClip {
    let samples: [Float]
    let sampleRate: Double
    var duration: Double { sampleRate > 0 ? Double(samples.count) / sampleRate : 0 }
    var isEffectivelySilent: Bool { samples.count < Int(sampleRate * 0.2) }  // < 0.2 s
}

/// Pluggable speech-to-text backend. New engines (Parakeet, whisper.cpp, a
/// cloud option, …) only need to conform to this and be added to the factory.
protocol TranscriptionEngine: AnyObject {
    var displayName: String { get }

    /// Download / load models. Idempotent; safe to call before every job.
    /// `progress` reports 0...1 during any one-time model download.
    func prepare(progress: (@Sendable (Double) -> Void)?) async throws

    func transcribe(_ clip: AudioClip) async throws -> String
}

extension TranscriptionEngine {
    func prepare(progress: (@Sendable (Double) -> Void)?) async throws {}
}

/// A live transcription session: audio is fed in as it's captured, partial text
/// is available while speaking, and the final text is returned on stop.
protocol LiveTranscriptionSession: Sendable {
    /// Feed a 16 kHz mono chunk. Safe to call from the audio thread; ordered.
    func append(_ chunk16k: [Float])
    /// Transcript so far, split into `confirmed` (stable) and `volatile` (the
    /// still-settling tail) so the UI can render the tail dimmed and avoid the
    /// jank of showing the token-by-token in-flight decode.
    func partialParts() async -> (confirmed: String, volatile: String)
    /// Stop, decode the remaining tail, and return the full transcript.
    func finish() async -> String
}

/// A transcription engine that can also run in streaming mode.
protocol StreamingCapable: AnyObject {
    func startStreamingSession() async throws -> LiveTranscriptionSession
}

enum TranscriptionError: LocalizedError {
    case localeUnsupported(String)
    case noCompatibleAudioFormat
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .localeUnsupported(let l): return "Locale \(l) isn't supported for on-device transcription."
        case .noCompatibleAudioFormat:  return "Couldn't negotiate an audio format with the transcriber."
        case .emptyResult:              return "Transcription produced no text."
        }
    }
}

/// Builds the engine selected in settings.
enum TranscriptionEngineFactory {
    static func make(_ settings: AppSettings) -> TranscriptionEngine {
        switch settings.sttEngine {
        case .whisperKit:
            let lang = settings.whisperLanguage.lowercased()
            return WhisperKitEngine(model: settings.whisperModel,
                                    language: lang == "auto" ? nil : lang)
        case .appleSpeech:
            return AppleSpeechEngine(localeIdentifier: settings.appleSpeechLocale)
        }
    }
}
