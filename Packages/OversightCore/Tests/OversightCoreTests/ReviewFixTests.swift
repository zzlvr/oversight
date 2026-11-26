import XCTest
@testable import OversightCore

final class ReviewFixTests: XCTestCase {
    private struct RefusingStore: SecretStore {
        func get(_ key: String) -> String? { nil }
        func set(_ value: String, for key: String) throws { throw KeychainError(status: -1) }
    }

    func testQuestionsShareOneNetworkSession() {
        let first = AnswerService(provider: provider(for: .claude))
        let second = AnswerService(provider: provider(for: .gemini))
        XCTAssertTrue(first.session === second.session)
    }

    func testModelNameWithATrailingNewlineIsRefused() {
        for kind in ProviderKind.allCases {
            XCTAssertThrowsError(try provider(for: kind).makeRequest(prompt: "p", jpeg: Data([1]), apiKey: "k", model: "m\n")) {
                XCTAssertEqual($0 as? AssistError, .invalidModel)
            }
        }
    }

    func testIdentityStaysStableWhenTheKeychainRefusesToSave() {
        let name = "oversight.tests.\(UUID().uuidString)"
        let fallback = UserDefaults(suiteName: name)!
        let first = FrameIdentity.load(from: RefusingStore(), fallback: fallback)
        let second = FrameIdentity.load(from: RefusingStore(), fallback: fallback)
        XCTAssertEqual(first.publicKey, second.publicKey)
        fallback.removePersistentDomain(forName: name)
    }
}
