import Foundation

struct OpenAIProvider: VisionProvider {
    func makeRequest(prompt: String, jpeg: Data, apiKey: String, model: String) throws -> URLRequest {
        let key = try ProviderSupport.requireKey(apiKey)
        try ProviderSupport.requireModel(model)
        var body: [String: Any] = [
            "model": model,
            "max_completion_tokens": 4096,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url",
                     "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]],
                ],
            ]],
        ]
        if model.hasPrefix("gpt-6") {
            body["reasoning_effort"] = "low"
        }
        return try ProviderSupport.request(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            headers: ["Authorization": "Bearer \(key)"],
            body: body)
    }

    func parseAnswer(data: Data, status: Int) throws -> String {
        try ProviderSupport.checkStatus(status, data: data)
        let choices = ProviderSupport.json(data)?["choices"] as? [[String: Any]] ?? []
        let message = choices.first?["message"] as? [String: Any]
        return try ProviderSupport.finish(message?["content"] as? String ?? "")
    }
}
