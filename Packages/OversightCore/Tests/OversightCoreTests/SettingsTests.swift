import XCTest
@testable import OversightCore

final class KeychainStoreTests: XCTestCase {
    private func makeStore() -> KeychainStore {
        KeychainStore(service: "oversight.tests.\(UUID().uuidString)")
    }

    func testKeychainRoundTrip() throws {
        let store = makeStore()
        try store.set("secret-123", for: "claude")
        XCTAssertEqual(store.get("claude"), "secret-123")
        store.remove("claude")
    }

    func testSetOverwritesExistingValue() throws {
        let store = makeStore()
        try store.set("one", for: "k")
        try store.set("two", for: "k")
        XCTAssertEqual(store.get("k"), "two")
        store.remove("k")
    }

    func testRemoveDeletesValue() throws {
        let store = makeStore()
        try store.set("x", for: "k")
        store.remove("k")
        XCTAssertNil(store.get("k"))
    }

    func testGetMissingReturnsNil() {
        XCTAssertNil(makeStore().get("nothing"))
    }
}

final class AppSettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "oversight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testSettingsDefaults() {
        let settings = AppSettings(defaults: freshDefaults())
        XCTAssertEqual(settings.provider, .gemini)
        XCTAssertEqual(settings.language, .system)
        XCTAssertEqual(settings.effectiveModel, ProviderKind.gemini.defaultModel)
    }

    func testSettingsPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = AppSettings(defaults: defaults)
        first.provider = .gemini
        first.language = .ru
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.provider, .gemini)
        XCTAssertEqual(second.language, .ru)
    }

    func testModelIsStoredPerProvider() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.provider = .claude
        settings.setModel("my-claude-model", for: .claude)
        settings.provider = .openai
        XCTAssertEqual(settings.effectiveModel, ProviderKind.openai.defaultModel)
        settings.provider = .claude
        XCTAssertEqual(settings.effectiveModel, "my-claude-model")
    }

    func testBlankModelFallsBackToDefault() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.provider = .claude
        settings.setModel("   ", for: .claude)
        XCTAssertEqual(settings.effectiveModel, ProviderKind.claude.defaultModel)
    }

    func testSomeoneWhoAlreadySavedAKeyKeepsThatProvider() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.keepProviderWithKey { $0 == .claude }
        XCTAssertEqual(settings.provider, .claude)
    }

    func testNewUserGetsGemini() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.keepProviderWithKey { _ in false }
        XCTAssertEqual(settings.provider, .gemini)
    }

    func testChosenProviderIsNeverOverridden() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.provider = .openai
        settings.keepProviderWithKey { $0 == .claude }
        XCTAssertEqual(settings.provider, .openai)
    }

    func testKeyPages() {
        XCTAssertEqual(ProviderKind.gemini.keyPageURL.absoluteString, "https://aistudio.google.com/api-keys")
        XCTAssertEqual(ProviderKind.claude.keyPageURL.host, "console.anthropic.com")
        XCTAssertEqual(ProviderKind.openai.keyPageURL.host, "platform.openai.com")
    }

    func testLanguageLocaleIdentifiers() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.en.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.ru.localeIdentifier, "ru")
    }
}
