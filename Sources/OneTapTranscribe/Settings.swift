import Foundation
import Combine

// MARK: - Enumerations for the pluggable backends

enum STTEngineKind: String, Codable, CaseIterable, Identifiable {
    case whisperKit
    case appleSpeech
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .whisperKit:  return "WhisperKit (OpenAI Whisper, local)"
        case .appleSpeech: return "Apple SpeechTranscriber (built-in)"
        }
    }
}

/// WhisperKit model identifiers. `whisperKitName` is the exact variant string
/// WhisperKit globs against the `argmaxinc/whisperkit-coreml` Hugging Face repo
/// and downloads on first use.
enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    case tiny
    case base
    case small
    case distilLargeV3Turbo
    case largeV3Turbo
    case largeV3
    var id: String { rawValue }

    var whisperKitName: String {
        switch self {
        case .tiny:               return "tiny"
        case .base:               return "base"
        case .small:              return "small"
        case .distilLargeV3Turbo: return "distil-large-v3_turbo_600MB"
        case .largeV3Turbo:       return "large-v3-v20240930_turbo_632MB"
        case .largeV3:            return "large-v3-v20240930_626MB"
        }
    }

    var displayName: String {
        switch self {
        case .tiny:               return "tiny (~75 MB, fastest)"
        case .base:               return "base (~145 MB)"
        case .small:              return "small (~470 MB)"
        case .distilLargeV3Turbo: return "distil-large-v3 turbo (~600 MB, fastest large-quality)"
        case .largeV3Turbo:       return "large-v3 turbo (~632 MB, fast + accurate)"
        case .largeV3:            return "large-v3 (~626 MB, most accurate)"
        }
    }
}

enum CleanupKind: String, Codable, CaseIterable, Identifiable {
    case none
    case appleFoundation
    case ollama
    case openAICompatible   // MLX (mlx_lm.server), LM Studio, llama.cpp, vLLM…
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none:             return "None (raw transcript)"
        case .appleFoundation:  return "Apple Foundation Models (on-device)"
        case .ollama:           return "Ollama (local server)"
        case .openAICompatible: return "MLX / OpenAI-compatible server"
        }
    }
}

/// Push-to-talk key. Modifier keys are used as press-and-hold triggers.
enum TriggerKey: String, Codable, CaseIterable, Identifiable {
    case fn
    case rightCommand
    case rightOption
    case rightControl
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fn:            return "Fn (globe) key"
        case .rightCommand:  return "Right ⌘ Command"
        case .rightOption:   return "Right ⌥ Option"
        case .rightControl:  return "Right ⌃ Control"
        }
    }
}

// MARK: - Default prompts (all editable in Settings)

enum DefaultPrompts {
    static let cleanupSystem = """
    You are a transcription cleanup assistant. You are given raw speech-to-text \
    output and you return a cleaned-up version of the same text.

    Rules:
    - Remove filler words (um, uh, er, like, you know).
    - Fix punctuation, capitalization, and obvious transcription mistakes.
    - Keep the speaker's own wording, tone, and meaning. Do not paraphrase.
    - Do NOT answer questions, add commentary, summarize, or translate.
    - Output ONLY the cleaned text. No preamble, no quotes, no explanations.
    """

    /// `{{text}}` is replaced with the raw transcript at runtime.
    static let cleanupUserTemplate = "{{text}}"
}

// MARK: - Settings model

struct AppSettings: Codable, Equatable {
    var sttEngine: STTEngineKind = .whisperKit
    var whisperModel: WhisperModel = .largeV3
    /// Whisper transcription language ("en", "es", …) or "auto" to detect.
    var whisperLanguage: String = "en"
    var appleSpeechLocale: String = "en-US"

    var cleanup: CleanupKind = .appleFoundation

    // Ollama (native API)
    var ollamaEndpoint: String = "http://localhost:11434"
    var ollamaModel: String = ""

    // OpenAI-compatible server — MLX (`mlx_lm.server`, default :8080),
    // LM Studio (:1234), llama.cpp `llama-server` (:8080), vLLM, …
    var openAIEndpoint: String = "http://localhost:8080"
    var openAIModel: String = ""
    var openAIAPIKey: String = ""   // usually blank for local servers

    var triggerKey: TriggerKey = .rightCommand

    var cleanupSystemPrompt: String = DefaultPrompts.cleanupSystem
    var cleanupUserTemplate: String = DefaultPrompts.cleanupUserTemplate

    /// Paste via clipboard + ⌘V (true) vs. synthesizing each keystroke (false).
    var pasteInsteadOfType: Bool = true
    var playFeedbackSounds: Bool = true

    /// When true: menu-bar icon only, no Dock icon. When false (default): also
    /// show a Dock icon + main window, so the app is easy to find.
    var menuBarOnly: Bool = false

    /// Show the floating recording overlay (waveform → "Transcribing…") at the
    /// bottom-center of the screen while dictating.
    var showOverlay: Bool = true
}

// MARK: - Persistence

/// Observable wrapper that persists `AppSettings` to UserDefaults as JSON.
@MainActor
final class SettingsStore: ObservableObject {
    private static let key = "AppSettings.v1"

    @Published var settings: AppSettings {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
