import Foundation
import WhisperKit

/// OpenAI Whisper running fully on-device via WhisperKit (Core ML).
///
/// The model is downloaded from Hugging Face on first use and cached in
/// Application Support; subsequent launches load from disk.
final class WhisperKitEngine: TranscriptionEngine {
    let displayName = "WhisperKit"

    private let modelName: String
    private let language: String?
    private var pipe: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    init(model: WhisperModel, language: String?) {
        self.modelName = model.whisperKitName
        self.language = language
    }

    func prepare(progress: (@Sendable (Double) -> Void)?) async throws {
        _ = try await loadedPipe()
    }

    /// Loads the model once, coalescing concurrent callers (prewarm + first
    /// record) onto a single load task. Config-based init auto-downloads on
    /// first run then loads before returning.
    private func loadedPipe() async throws -> WhisperKit {
        if let pipe { return pipe }
        if let loadTask { return try await loadTask.value }

        let name = modelName
        let task = Task { try await WhisperKit(WhisperKitConfig(model: name)) }
        loadTask = task
        do {
            let loaded = try await task.value
            pipe = loaded
            return loaded
        } catch {
            loadTask = nil
            throw error
        }
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        let pipe = try await loadedPipe()

        let options = DecodingOptions(
            task: .transcribe,
            language: language,          // nil = auto-detect
            temperature: 0.0,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results = try await pipe.transcribe(audioArray: clip.samples, decodeOptions: options)
        return results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension WhisperKitEngine: StreamingCapable {
    func startStreamingSession() async throws -> LiveTranscriptionSession {
        let pipe = try await loadedPipe()
        let session = WhisperLiveSession(whisper: pipe, language: language)
        await session.start()
        return session
    }
}
