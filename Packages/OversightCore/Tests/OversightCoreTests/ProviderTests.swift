import XCTest
@testable import OversightCore

final class ProviderTests: XCTestCase {
    private let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
    private var jpegBase64: String { jpeg.base64EncodedString() }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Claude

    func testClaudeRequestShape() throws {
        let request = try provider(for: .claude)
            .makeRequest(prompt: "Where do I tap?", jpeg: jpeg, apiKey: "k1", model: "claude-sonnet-5-5")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "k1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let json = try body(request)
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-5-5")
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
        let image = try XCTUnwrap(content.first { $0["type"] as? String == "image" })
        let source = try XCTUnwrap(image["source"] as? [String: Any])
        XCTAssertEqual(source["media_type"] as? String, "image/jpeg")
        XCTAssertEqual(source["data"] as? String, jpegBase64)
        let text = try XCTUnwrap(content.first { $0["type"] as? String == "text" })
        XCTAssertEqual(text["text"] as? String, "Where do I tap?")
    }

    func testClaudeParsesAnswer() throws {
        let data = Data(#"{"content":[{"type":"text","text":"Tap the red button."}]}"#.utf8)
        XCTAssertEqual(try provider(for: .claude).parseAnswer(data: data, status: 200), "Tap the red button.")
    }

    func testClaude401MapsToHttpErrorWithMessage() {
        let data = Data(#"{"error":{"type":"authentication_error","message":"invalid x-api-key"}}"#.utf8)
        XCTAssertThrowsError(try provider(for: .claude).parseAnswer(data: data, status: 401)) {
            XCTAssertEqual($0 as? AssistError, .http(status: 401, message: "invalid x-api-key"))
        }
    }

    // MARK: OpenAI

    func testOpenAIRequestShape() throws {
        let request = try provider(for: .openai)
            .makeRequest(prompt: "Translate", jpeg: jpeg, apiKey: "k2", model: "gpt-4o")
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer k2")
        let json = try body(request)
        XCTAssertEqual(json["model"] as? String, "gpt-4o")
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
        let image = try XCTUnwrap(content.first { $0["type"] as? String == "image_url" })
        let url = try XCTUnwrap((image["image_url"] as? [String: Any])?["url"] as? String)
        XCTAssertEqual(url, "data:image/jpeg;base64,\(jpegBase64)")
    }

    func testOpenAIParsesAnswer() throws {
        let data = Data(#"{"choices":[{"message":{"content":"Choose size M."}}]}"#.utf8)
        XCTAssertEqual(try provider(for: .openai).parseAnswer(data: data, status: 200), "Choose size M.")
    }

    // MARK: Gemini

    func testGeminiRequestShape() throws {
        let request = try provider(for: .gemini)
            .makeRequest(prompt: "Is it a good deal?", jpeg: jpeg, apiKey: "k3", model: "gemini-2.0-flash")
        XCTAssertEqual(request.url?.absoluteString,
                       "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "k3")
        let json = try body(request)
        let contents = try XCTUnwrap(json["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        let inline = try XCTUnwrap(parts.compactMap { $0["inline_data"] as? [String: Any] }.first)
        XCTAssertEqual(inline["mime_type"] as? String, "image/jpeg")
        XCTAssertEqual(inline["data"] as? String, jpegBase64)
    }

    func testGeminiParsesAnswer() throws {
        let data = Data(#"{"candidates":[{"content":{"parts":[{"text":"Looks fair."}]}}]}"#.utf8)
        XCTAssertEqual(try provider(for: .gemini).parseAnswer(data: data, status: 200), "Looks fair.")
    }

    // MARK: Shared behaviour

    func testEmptyKeyThrowsMissingKey() {
        for kind in ProviderKind.allCases {
            XCTAssertThrowsError(try provider(for: kind).makeRequest(prompt: "x", jpeg: jpeg, apiKey: "  ", model: "m")) {
                XCTAssertEqual($0 as? AssistError, .missingKey)
            }
        }
    }

    func testEmptyAnswerThrows() {
        let data = Data(#"{"content":[{"type":"text","text":"   "}]}"#.utf8)
        XCTAssertThrowsError(try provider(for: .claude).parseAnswer(data: data, status: 200)) {
            XCTAssertEqual($0 as? AssistError, .emptyAnswer)
        }
    }

    func testNonJSONErrorBodyStillMapsToHttpError() {
        XCTAssertThrowsError(try provider(for: .openai).parseAnswer(data: Data("oops".utf8), status: 500)) {
            XCTAssertEqual($0 as? AssistError, .http(status: 500, message: "Request failed"))
        }
    }

    func testChineseAnswerIsPreserved() throws {
        let data = Data(#"{"choices":[{"message":{"content":"点击“立即购买”"}}]}"#.utf8)
        XCTAssertEqual(try provider(for: .openai).parseAnswer(data: data, status: 200), "点击“立即购买”")
    }

    func testDefaultModelsAreNotEmpty() {
        for kind in ProviderKind.allCases { XCTAssertFalse(kind.defaultModel.isEmpty) }
    }
}
