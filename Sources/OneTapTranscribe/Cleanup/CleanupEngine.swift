import Foundation

/// Pluggable transcript-cleanup backend (a local LLM that tidies the raw STT
/// output using a user-editable prompt).
protocol CleanupEngine: AnyObject {
    var displayName: String { get }

    /// Whether this backend can run right now (model present / server reachable).
    func availability() async -> CleanupAvailability

    /// Returns the cleaned text. Implementations MUST fall back to returning
    /// `text` unchanged on any failure rather than throwing away the user's
    /// words — a dictation tool should never lose a transcript.
    func clean(_ text: String, systemPrompt: String, userTemplate: String) async throws -> String
}

enum CleanupAvailability {
    case available
    case unavailable(String)   // reason, shown in Settings

    var isAvailable: Bool { if case .available = self { return true }; return false }
    var reason: String? { if case .unavailable(let r) = self { return r }; return nil }
}

extension CleanupEngine {
    /// Substitutes the transcript into the `{{text}}` placeholder. If the
    /// template has no placeholder, the transcript is appended.
    func renderPrompt(_ template: String, text: String) -> String {
        if template.contains("{{text}}") {
            return template.replacingOccurrences(of: "{{text}}", with: text)
        }
        return template.isEmpty ? text : template + "\n\n" + text
    }
}

enum CleanupEngineFactory {
    static func make(_ settings: AppSettings) -> CleanupEngine {
        switch settings.cleanup {
        case .none:
            return PassthroughCleanup()
        case .appleFoundation:
            return FoundationModelsEngine()
        case .ollama:
            return OllamaCleanup(endpoint: settings.ollamaEndpoint, model: settings.ollamaModel)
        case .openAICompatible:
            return OpenAICompatibleCleanup(
                endpoint: settings.openAIEndpoint,
                model: settings.openAIModel,
                apiKey: settings.openAIAPIKey
            )
        }
    }
}

/// No-op cleanup: return the raw transcript.
final class PassthroughCleanup: CleanupEngine {
    let displayName = "None"
    func availability() async -> CleanupAvailability { .available }
    func clean(_ text: String, systemPrompt: String, userTemplate: String) async throws -> String { text }
}
