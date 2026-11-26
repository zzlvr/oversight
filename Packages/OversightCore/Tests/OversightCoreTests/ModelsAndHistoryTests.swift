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
    func testMarkedScreensAreKeptOldestFirst() {
        let history = ScreenHistory()
        history.mark(Data([1]))
        history.mark(Data([2]))
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([1]), Data([2])])
    }

    func testMarkingTheSameFrameAgainDoesNotDuplicateIt() {
        let history = ScreenHistory()
        history.mark(Data([1]))
        history.mark(Data([1]))
        XCTAssertEqual(history.screens.count, 1)
    }

    func testOnlyTheNewestAreKept() {
        let history = ScreenHistory(capacity: 2)
        for value: UInt8 in 0..<4 { history.mark(Data([value])) }
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([2]), Data([3])])
    }

    func testClearForgetsEverything() {
        let history = ScreenHistory()
        history.mark(Data([1]))
        history.clear()
        XCTAssertTrue(history.screens.isEmpty)
    }
}

final class RecentFramesTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testPicksTheFrameFromJustBeforeAMoment() {
        let recent = RecentFrames()
        for step in 0..<4 { recent.add(Data([UInt8(step)]), at: start + Double(step)) }
        XCTAssertEqual(recent.frame(before: start + 2.3), Data([2]))
    }

    func testStaticScreenKeepsItsOldFrame() {
        let recent = RecentFrames()
        recent.add(Data([7]), at: start)
        XCTAssertEqual(recent.frame(before: start + 60), Data([7]))
    }

    func testFallsBackToTheOldestKept() {
        let recent = RecentFrames(capacity: 2)
        for step in 0..<3 { recent.add(Data([UInt8(step)]), at: start + Double(step)) }
        XCTAssertEqual(recent.frame(before: start), Data([1]))
    }

    func testClearForgetsEverything() {
        let recent = RecentFrames()
        recent.add(Data([1]), at: start)
        recent.clear()
        XCTAssertNil(recent.frame(before: start + 1))
    }
}
