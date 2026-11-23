import Foundation

struct GeminiProvider: VisionProvider {
    func makeRequest(prompt: String, jpeg: Data, apiKey: String, model: String) throws -> URLRequest {
        let key = try ProviderSupport.requireKey(apiKey)
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent") else {
            throw AssistError.http(status: 0, message: "Invalid model name")
        }
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                ],
            ]],
        ]
        return try ProviderSupport.request(url: url, headers: ["x-goog-api-key": key], body: body)
    }

    func parseAnswer(data: Data, status: Int) throws -> String {
        try ProviderSupport.checkStatus(status, data: data)
        let candidates = ProviderSupport.json(data)?["candidates"] as? [[String: Any]] ?? []
        let content = candidates.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]] ?? []
        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        return try ProviderSupport.finish(text)
    }
}
