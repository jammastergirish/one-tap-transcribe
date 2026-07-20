import Foundation

/// Cleanup via any OpenAI-compatible `/v1/chat/completions` server. Covers MLX
/// (`mlx_lm.server`), LM Studio, llama.cpp `llama-server`, vLLM, etc.
final class OpenAICompatibleCleanup: CleanupEngine {
    let displayName = "MLX / OpenAI-compatible"

    private let base: URL
    private let model: String
    private let apiKey: String

    init(endpoint: String, model: String, apiKey: String) {
        self.base = URL(string: endpoint) ?? URL(string: "http://localhost:8080")!
        self.model = model
        self.apiKey = apiKey
    }

    func availability() async -> CleanupAvailability {
        guard let models = await SystemDetector.openAIModels(endpoint: base.absoluteString, apiKey: apiKey) else {
            return .unavailable("No server reachable at \(base.absoluteString). For MLX: `mlx_lm.server --port 8080`.")
        }
        if model.isEmpty {
            return models.isEmpty
                ? .unavailable("Server reachable but exposes no models.")
                : .unavailable("No model selected.")
        }
        // Some servers (mlx_lm) accept any model id; treat a reachable server
        // with a chosen model as usable even if the id isn't in /v1/models.
        return .available
    }

    func clean(_ text: String, systemPrompt: String, userTemplate: String) async throws -> String {
        let url = base.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15   // bounded so a hung server can't stall dictation

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": renderPrompt(userTemplate, text: text)]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct Resp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let cleaned = (decoded.choices.first?.message.content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? text : cleaned
    }
}
