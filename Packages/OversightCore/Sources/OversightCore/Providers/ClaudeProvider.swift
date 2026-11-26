import Foundation

struct ClaudeProvider: VisionProvider {
    func makeRequest(prompt: String, jpeg: Data, apiKey: String, model: String) throws -> URLRequest {
        let key = try ProviderSupport.requireKey(apiKey)
        try ProviderSupport.requireModel(model)
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": prompt],
                ],
            ]],
        ]
        // Haiku 5 thinks by default; low effort keeps answers quick and cheap.
        if model.hasPrefix("claude-haiku-5") {
            body["output_config"] = ["effort": "low"]
        }
        return try ProviderSupport.request(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: ["x-api-key": key, "anthropic-version": "2023-06-01"],
            body: body)
    }

    func parseAnswer(data: Data, status: Int) throws -> String {
        try ProviderSupport.checkStatus(status, data: data)
        let blocks = ProviderSupport.json(data)?["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
        return try ProviderSupport.finish(text)
    }
}
