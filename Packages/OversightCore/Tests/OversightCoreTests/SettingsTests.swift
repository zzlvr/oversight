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
        XCTAssertEqual(settings.provider, .claude)
        XCTAssertEqual(settings.language, .system)
        XCTAssertEqual(settings.effectiveModel, ProviderKind.claude.defaultModel)
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
        settings.setModel("   ", for: .claude)
        XCTAssertEqual(settings.effectiveModel, ProviderKind.claude.defaultModel)
    }

    func testLanguageLocaleIdentifiers() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.en.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.ru.localeIdentifier, "ru")
    }
}
