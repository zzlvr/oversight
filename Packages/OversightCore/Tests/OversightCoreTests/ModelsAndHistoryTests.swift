import XCTest
@testable import OversightCore

final class CheapModelTests: XCTestCase {
    private func body(_ kind: ProviderKind, model: String) throws -> [String: Any] {
        let request = try provider(for: kind).makeRequest(prompt: "p", jpeg: Data([1]), apiKey: "k", model: model)
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testDefaultModelsAreTheInexpensiveOnes() {
        XCTAssertEqual(ProviderKind.claude.defaultModel, "claude-haiku-5-5")
        XCTAssertEqual(ProviderKind.openai.defaultModel, "gpt-6-luna")
        XCTAssertEqual(ProviderKind.gemini.defaultModel, "gemini-3.5-flash-lite")
    }

    func testHaikuRunsAtLowEffortWithRoomForThinking() throws {
        let json = try body(.claude, model: "claude-haiku-5-5")
        XCTAssertEqual((json["output_config"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertEqual(json["max_tokens"] as? Int, 4096)
    }

    func testOtherClaudeModelsGetNoEffortSetting() throws {
        XCTAssertNil(try body(.claude, model: "claude-haiku-4-5")["output_config"])
    }

    func testGpt6RunsAtLowReasoningEffort() throws {
        let json = try body(.openai, model: "gpt-6-luna")
        XCTAssertEqual(json["reasoning_effort"] as? String, "low")
        XCTAssertEqual(json["max_completion_tokens"] as? Int, 4096)
        XCTAssertNil(try body(.openai, model: "gpt-4o-mini")["reasoning_effort"])
    }

    func testSystemPromptAsksForShortAnswers() {
        XCTAssertTrue(defaultSystemPrompt.contains("under 300 characters"))
    }
}

final class ScreenHistoryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testFramesCloseInTimeReplaceEachOther() {
        let history = ScreenHistory(capacity: 6, spacing: 2)
        history.add(Data([1]), at: start)
        history.add(Data([2]), at: start + 1)
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([2])])
    }

    func testReplacingKeepsTheSameIdentifier() {
        let history = ScreenHistory(capacity: 6, spacing: 2)
        history.add(Data([1]), at: start)
        let id = history.screens[0].id
        history.add(Data([2]), at: start + 1)
        XCTAssertEqual(history.screens[0].id, id)
    }

    func testSteadyStreamStillStartsNewEntries() {
        let history = ScreenHistory(capacity: 6, spacing: 2)
        for step in 0..<8 { history.add(Data([UInt8(step)]), at: start + Double(step) * 0.5) }
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([3]), Data([7])])
    }

    func testOnlyTheNewestAreKept() {
        let history = ScreenHistory(capacity: 2, spacing: 2)
        for step in 0..<4 { history.add(Data([UInt8(step)]), at: start + Double(step) * 3) }
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([2]), Data([3])])
    }

    func testScreenBeforeADateSkipsTheTransitionFrames() {
        let history = ScreenHistory(capacity: 6, spacing: 2)
        history.add(Data([1]), at: start)
        history.add(Data([2]), at: start + 10)
        XCTAssertEqual(history.screen(before: start + 9)?.jpeg, Data([1]))
        XCTAssertEqual(history.screen(before: start - 5)?.jpeg, Data([1]))
    }

    func testClearForgetsEverything() {
        let history = ScreenHistory(capacity: 6, spacing: 2)
        history.add(Data([1]), at: start)
        history.clear()
        XCTAssertTrue(history.screens.isEmpty)
        XCTAssertNil(history.screen(before: start))
    }
}
