import Foundation
import FoundationModels

/// Runtime probes for what cleanup backends are actually available on this
/// machine, so Settings can list the user's installed models.
enum SystemDetector {

    // MARK: Apple Foundation Models

    static func appleFoundationAvailable() -> Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: Ollama (native API)

    /// Model names from a local Ollama server, or `nil` if unreachable.
    static func ollamaModels(endpoint: String) async -> [String]? {
        guard let url = URL(string: endpoint)?.appendingPathComponent("api/tags") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Decodable { struct M: Decodable { let name: String }; let models: [M] }
            return try JSONDecoder().decode(Resp.self, from: data).models.map { $0.name }
        } catch {
            return nil
        }
    }

    // MARK: OpenAI-compatible server (MLX / LM Studio / llama.cpp / vLLM)

    /// Model ids from an OpenAI-compatible `/v1/models`, or `nil` if unreachable.
    static func openAIModels(endpoint: String, apiKey: String) async -> [String]? {
        guard let url = URL(string: endpoint)?.appendingPathComponent("v1/models") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Decodable { struct M: Decodable { let id: String }; let data: [M] }
            return try JSONDecoder().decode(Resp.self, from: data).data.map { $0.id }
        } catch {
            return nil
        }
    }
}
