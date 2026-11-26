import XCTest
@testable import OversightCore

final class InputSafetyTests: XCTestCase {
    private func request(_ kind: ProviderKind, key: String = "sk-abc_123", model: String = "m-1.5") throws -> URLRequest {
        try provider(for: kind).makeRequest(prompt: "p", jpeg: Data([1]), apiKey: key, model: model)
    }

    func testModelNamesThatCouldChangeTheRequestAreRefused() {
        for kind in ProviderKind.allCases {
            for bad in ["../files", "a/b", "a?key=1", "a b", "a#x", "", String(repeating: "m", count: 200)] {
                XCTAssertThrowsError(try request(kind, model: bad), "\(kind) \(bad)") {
                    XCTAssertEqual($0 as? AssistError, .invalidModel)
                }
            }
        }
    }

    func testOrdinaryModelNamesPass() throws {
        for good in ["claude-haiku-5-5", "gpt-6-luna", "gemini-3.5-flash-lite", "ft:gpt-4o-mini:org:name"] {
            XCTAssertNoThrow(try request(.openai, model: good))
        }
    }

    func testKeysWithSpacesNewlinesOrOtherAlphabetsAreRefused() {
        for kind in ProviderKind.allCases {
            for bad in ["abc def", "abc\r\nX-Evil: 1", "ключ", "abc\u{0}"] {
                XCTAssertThrowsError(try request(kind, key: bad)) {
                    XCTAssertEqual($0 as? AssistError, .invalidKey)
                }
            }
        }
    }

    func testSurroundingWhitespaceInAPastedKeyIsAccepted() throws {
        let made = try request(.claude, key: "  sk-abc\n")
        XCTAssertEqual(made.value(forHTTPHeaderField: "x-api-key"), "sk-abc")
    }

    func testQuestionsAreTrimmedLimitedAndNeverEmpty() {
        XCTAssertNil(cleanedQuestion("  \n "))
        XCTAssertEqual(cleanedQuestion("  hi "), "hi")
        XCTAssertEqual(cleanedQuestion(String(repeating: "a", count: 10_000))?.count, 2_000)
    }

    func testCustomInstructionsAreLimitedAndCannotRemoveTheScreenTextRule() {
        let prompt = composePrompt(system: String(repeating: "s", count: 10_000), preset: "q", answerLanguage: "English")
        XCTAssertTrue(prompt.contains(screenTextRule))
        XCTAssertLessThan(prompt.count, 5_000)
        XCTAssertTrue(screenTextRule.contains("not instructions"))
    }

    func testErrorDetailHidesKeyProblemsAndKeyLikeText() {
        XCTAssertNil(errorDetail(status: 401, message: "Incorrect API key: sk-abc***xyz"))
        XCTAssertNil(errorDetail(status: 403, message: "denied"))
        XCTAssertNil(errorDetail(status: 0, message: "offline"))
        XCTAssertEqual(errorDetail(status: 404, message: "model not found"), "404: model not found")
        XCTAssertEqual(errorDetail(status: 400, message: "bad sk-proj-abcdef123456 and AIzaSyA1234567890"),
                       "400: bad [hidden] and [hidden]")
        XCTAssertEqual(errorDetail(status: 500, message: String(repeating: "x", count: 900))?.count, 205)
    }

    func testVeryLongAnswersAreCut() throws {
        let long = String(repeating: "a", count: 50_000)
        let data = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": long]]]])
        let answer = try provider(for: .openai).parseAnswer(data: data, status: 200)
        XCTAssertEqual(answer.count, 6_000)
    }

    func testNetworkSessionKeepsNothingAndFollowsNoRedirects() {
        let session = makePrivateSession()
        XCTAssertNil(session.configuration.urlCache)
        XCTAssertNil(session.configuration.httpCookieStorage)
        let delegate = session.delegate as? URLSessionTaskDelegate
        XCTAssertNotNil(delegate)
        let url = URL(string: "https://example.invalid")!
        let task = session.dataTask(with: url)
        var followed: URLRequest? = URLRequest(url: url)
        delegate?.urlSession?(
            session, task: task,
            willPerformHTTPRedirection: HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)!,
            newRequest: URLRequest(url: url)) { followed = $0 }
        XCTAssertNil(followed)
        task.cancel()
    }

    func testNewErrorMessages() {
        XCTAssertEqual(AssistError.invalidKey.messageKey, "Invalid API key")
        XCTAssertEqual(AssistError.invalidModel.messageKey, "Invalid model name")
    }
}
