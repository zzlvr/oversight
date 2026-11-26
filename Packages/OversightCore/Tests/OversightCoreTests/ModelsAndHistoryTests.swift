import XCTest
import CoreGraphics
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

    /// A flat signature: frames with close values look the same.
    private func look(_ value: UInt8) -> [UInt8] { [UInt8](repeating: value, count: 8) }

    /// Feeds one unchanged screen every half second for two seconds.
    private func hold(_ history: ScreenHistory, _ value: UInt8, from time: TimeInterval) {
        for step in 0...4 {
            history.add(Data([value]), signature: look(value), at: start + time + Double(step) * 0.5)
        }
    }

    func testScreenIsKeptOnlyAfterItStaysStill() {
        let history = ScreenHistory()
        history.add(Data([1]), signature: look(10), at: start)
        history.add(Data([1]), signature: look(10), at: start + 1)
        XCTAssertTrue(history.screens.isEmpty)
        history.add(Data([1]), signature: look(10), at: start + 1.5)
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([1])])
    }

    func testMovingFramesAreNeverKept() {
        let history = ScreenHistory()
        for step in 0..<10 {
            history.add(Data([UInt8(step)]), signature: look(UInt8(step * 20)), at: start + Double(step) * 0.5)
        }
        XCTAssertTrue(history.screens.isEmpty)
    }

    func testSwitchingAwayDoesNotAddTheTransition() {
        let history = ScreenHistory()
        hold(history, 10, from: 0)
        history.add(Data([99]), signature: look(120), at: start + 2.5)
        history.add(Data([98]), signature: look(200), at: start + 3)
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([10])])
    }

    func testSmallChangesUpdateTheSameEntry() {
        let history = ScreenHistory()
        hold(history, 10, from: 0)
        let id = history.screens[0].id
        history.add(Data([13]), signature: look(13), at: start + 3)
        XCTAssertEqual(history.screens.map(\.id), [id])
        XCTAssertEqual(history.screens[0].jpeg, Data([13]))
    }

    func testReturningToTheSameScreenDoesNotDuplicateIt() {
        let history = ScreenHistory()
        hold(history, 10, from: 0)
        history.add(Data([99]), signature: look(120), at: start + 2.5)
        hold(history, 10, from: 3)
        XCTAssertEqual(history.screens.count, 1)
    }

    func testOnlyTheNewestAreKept() {
        let history = ScreenHistory(capacity: 2)
        hold(history, 10, from: 0)
        hold(history, 60, from: 3)
        hold(history, 120, from: 6)
        XCTAssertEqual(history.screens.map(\.jpeg), [Data([60]), Data([120])])
    }

    func testClearForgetsEverything() {
        let history = ScreenHistory()
        hold(history, 10, from: 0)
        history.clear()
        XCTAssertTrue(history.screens.isEmpty)
        history.add(Data([10]), signature: look(10), at: start + 5)
        XCTAssertTrue(history.screens.isEmpty)
    }

    func testSignatureTellsPicturesApart() throws {
        func jpeg(_ gray: CGFloat) throws -> Data {
            let context = CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 400))
            return try XCTUnwrap(downscaledJPEG(from: context.makeImage()!))
        }
        let dark = try XCTUnwrap(screenSignature(of: jpeg(0.1)))
        let darkAgain = try XCTUnwrap(screenSignature(of: jpeg(0.1)))
        let light = try XCTUnwrap(screenSignature(of: jpeg(0.9)))
        XCTAssertTrue(looksTheSame(dark, darkAgain))
        XCTAssertFalse(looksTheSame(dark, light))
        XCTAssertNil(screenSignature(of: Data([1, 2, 3])))
    }
}
