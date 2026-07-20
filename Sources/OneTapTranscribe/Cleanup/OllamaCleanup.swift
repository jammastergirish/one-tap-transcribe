import Foundation

/// Cleanup via a local Ollama server (native `/api/chat` endpoint).
final class OllamaCleanup: CleanupEngine {
    let displayName = "Ollama"

    private let base: URL
    private let model: String

    init(endpoint: String, model: String) {
        self.base = URL(string: endpoint) ?? URL(string: "http://localhost:11434")!
        self.model = model
    }

    func availability() async -> CleanupAvailability {
        guard let models = await SystemDetector.ollamaModels(endpoint: base.absoluteString) else {
            return .unavailable("No Ollama server reachable at \(base.absoluteString). Start it with `ollama serve`.")
        }
        if model.isEmpty {
            return .unavailable("No Ollama model selected.")
        }
        // Ollama tags may include a `:latest` suffix; match loosely.
        let ok = models.contains { $0 == model || $0.hasPrefix(model + ":") || model.hasPrefix($0) }
        return ok ? .available
                  : .unavailable("Model \"\(model)\" isn't pulled. Run `ollama pull \(model)`.")
    }

    func clean(_ text: String, systemPrompt: String, userTemplate: String) async throws -> String {
        let url = base.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": renderPrompt(userTemplate, text: text)]
            ],
            "options": ["temperature": 0.2]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct Resp: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let cleaned = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? text : cleaned
    }
}
