import XCTest
@testable import OversightCore

final class PresetStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "oversight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDefaultsAreSeededWhenStoreIsEmpty() {
        let store = PresetStore(defaults: freshDefaults())
        XCTAssertEqual(store.presets, PresetStore.defaultPresets)
        XCTAssertEqual(PresetStore.defaultPresets.map(\.title),
                       ["Translate screen", "Where do I tap?", "Is this a good deal?"])
    }

    func testPresetsPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = PresetStore(defaults: defaults)
        first.presets = [PromptPreset(id: UUID(), title: "Mine", prompt: "Explain this")]
        let second = PresetStore(defaults: defaults)
        XCTAssertEqual(second.presets.map(\.title), ["Mine"])
        XCTAssertEqual(second.presets.first?.prompt, "Explain this")
    }

    func testEmptyListIsKeptAfterUserDeletesEverything() {
        let defaults = freshDefaults()
        PresetStore(defaults: defaults).presets = []
        XCTAssertEqual(PresetStore(defaults: defaults).presets, [])
    }
}
