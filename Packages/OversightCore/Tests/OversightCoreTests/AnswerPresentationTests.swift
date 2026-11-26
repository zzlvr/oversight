import XCTest
@testable import OversightCore

final class TextPagerTests: XCTestCase {
    func testShortTextIsOnePage() {
        XCTAssertEqual(pages(for: "Tap Buy.", lineWidth: 34, linesPerPage: 8), ["Tap Buy."])
    }

    func testEmptyTextReturnsNoPages() {
        XCTAssertEqual(pages(for: "  \n ", lineWidth: 34, linesPerPage: 8), [])
    }

    func testLongTextSplitsOnWordBoundaries() {
        let result = pages(for: "alpha beta gamma delta", lineWidth: 11, linesPerPage: 1)
        XCTAssertEqual(result, ["alpha beta", "gamma delta"])
    }

    func testNewlinesAreKeptAndGroupedIntoPages() {
        XCTAssertEqual(pages(for: "a\nb\nc", lineWidth: 10, linesPerPage: 2), ["a\nb", "c"])
    }

    func testChineseWithoutSpacesCountsDoubleWidth() {
        XCTAssertEqual(pages(for: "立即购买立即购买", lineWidth: 8, linesPerPage: 1), ["立即购买", "立即购买"])
    }

    func testWordLongerThanALineIsSplit() {
        XCTAssertEqual(pages(for: "abcdefgh", lineWidth: 3, linesPerPage: 5), ["abc\ndef\ngh"])
    }
}

final class PromptComposerTests: XCTestCase {
    func testPromptContainsSystemTextPresetAndLanguage() {
        let prompt = composePrompt(system: "SYSTEM", preset: "Where do I tap?", answerLanguage: "Russian")
        XCTAssertTrue(prompt.hasPrefix("SYSTEM"))
        XCTAssertTrue(prompt.contains("Answer in Russian."))
        XCTAssertTrue(prompt.hasSuffix("Where do I tap?"))
    }

    func testDefaultSystemPromptTellsModelToIgnoreFloatingWindow() {
        XCTAssertTrue(defaultSystemPrompt.lowercased().contains("floating window"))
    }

    func testAnswerLanguageName() {
        XCTAssertEqual(answerLanguageName(for: .ru, preferred: ["en-US"]), "Russian")
        XCTAssertEqual(answerLanguageName(for: .en, preferred: ["ru-KZ"]), "English")
        XCTAssertEqual(answerLanguageName(for: .system, preferred: ["ru-KZ"]), "Russian")
        XCTAssertEqual(answerLanguageName(for: .system, preferred: []), "English")
    }

    func testCustomSystemPromptPersistsAndBlankRestoresDefault() {
        let name = "oversight.tests.\(UUID().uuidString)"
        let settings = AppSettings(defaults: UserDefaults(suiteName: name)!)
        XCTAssertEqual(settings.systemPrompt, defaultSystemPrompt)
        settings.systemPrompt = "Mine"
        XCTAssertEqual(settings.systemPrompt, "Mine")
        settings.systemPrompt = "   "
        XCTAssertEqual(settings.systemPrompt, defaultSystemPrompt)
    }
}

final class ErrorMessageTests: XCTestCase {
    func testMessageKeys() {
        XCTAssertEqual(AssistError.missingKey.messageKey, "Add your API key in Settings")
        XCTAssertEqual(AssistError.noFrame.messageKey, "No screen captured yet. Start the broadcast")
        XCTAssertEqual(AssistError.timeout.messageKey, "The request timed out. Try again")
        XCTAssertEqual(AssistError.emptyAnswer.messageKey, "The AI returned an empty answer")
        XCTAssertEqual(AssistError.busy.messageKey, "Still working on the last question")
        XCTAssertEqual(AssistError.http(status: 401, message: "x").messageKey, "Invalid API key")
        XCTAssertEqual(AssistError.http(status: 403, message: "x").messageKey, "Invalid API key")
        XCTAssertEqual(AssistError.http(status: 0, message: "x").messageKey, "No network connection")
        XCTAssertEqual(AssistError.http(status: 500, message: "x").messageKey, "The AI service returned an error")
    }

    func testFrameBufferCanBeCleared() {
        let buffer = FrameBuffer()
        buffer.store(Data([1]))
        buffer.clear()
        XCTAssertNil(buffer.latest())
    }
}
