import Foundation

public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case claude, openai, gemini

    /// Where the user creates an API key.
    public var keyPageURL: URL {
        switch self {
        case .claude: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/api-keys")!
        }
    }

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
        // A key is printable ASCII; anything else could break out of its header.
        guard trimmed.unicodeScalars.allSatisfy({ (0x21...0x7E).contains($0.value) }) else {
            throw AssistError.invalidKey
        }
        return trimmed
    }

    /// Model names go into request bodies and, for Gemini, into the URL.
    static func requireModel(_ model: String) throws {
        // \A and \z are the true start and end; "$" would also accept a trailing newline.
        let pattern = #"\A[A-Za-z0-9][A-Za-z0-9._:-]{0,99}\z"#
        guard model.range(of: pattern, options: .regularExpression) != nil else {
            throw AssistError.invalidModel
        }
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
        return String(trimmed.prefix(maxAnswerLength))
    }

    static func json(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
