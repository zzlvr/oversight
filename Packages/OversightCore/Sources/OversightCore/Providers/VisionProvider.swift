import Foundation

public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case claude, openai, gemini

    public var defaultModel: String {
        switch self {
        case .claude: return "claude-haiku-5-5"
        case .openai: return "gpt-6-luna"
        case .gemini: return "gemini-3.5-flash-lite"
        }
    }
}

public protocol VisionProvider: Sendable {
    func makeRequest(prompt: String, jpeg: Data, apiKey: String, model: String) throws -> URLRequest
    func parseAnswer(data: Data, status: Int) throws -> String
}

public func provider(for kind: ProviderKind) -> VisionProvider {
    switch kind {
    case .claude: return ClaudeProvider()
    case .openai: return OpenAIProvider()
    case .gemini: return GeminiProvider()
    }
}

enum ProviderSupport {
    static func requireKey(_ key: String) throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AssistError.missingKey }
        return trimmed
    }

    static func request(url: URL, headers: [String: String], body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Throws `.http` with the provider's own message for any non-2xx response.
    static func checkStatus(_ status: Int, data: Data) throws {
        guard !(200..<300).contains(status) else { return }
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (object?["error"] as? [String: Any])?["message"] as? String
        throw AssistError.http(status: status, message: message ?? "Request failed")
    }

    static func finish(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AssistError.emptyAnswer }
        return trimmed
    }

    static func json(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
