import Foundation
import FoundationModels

/// Cleanup via Apple's on-device model (Apple Intelligence). No download, no
/// server, no API key — but requires Apple Intelligence to be enabled.
final class FoundationModelsEngine: CleanupEngine {
    let displayName = "Apple Foundation Models"

    func availability() async -> CleanupAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Apple Intelligence isn't enabled. Turn it on in System Settings → Apple Intelligence & Siri.")
        case .unavailable(.deviceNotEligible):
            return .unavailable("This Mac can't run Apple's on-device model.")
        case .unavailable(.modelNotReady):
            return .unavailable("The on-device model is still downloading. Try again shortly.")
        case .unavailable:
            return .unavailable("Apple's on-device model is unavailable.")
        }
    }

    func clean(_ text: String, systemPrompt: String, userTemplate: String) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else { return text }

        let session = LanguageModelSession(instructions: systemPrompt)
        let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 4_000)
        let prompt = renderPrompt(userTemplate, text: text)

        let response = try await session.respond(to: prompt, options: options)
        let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? text : cleaned
    }
}
