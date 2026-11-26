import Foundation

public final class PresetStore {
    private let defaults: UserDefaults
    private let key = "oversight.presets"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static let defaultPresets: [PromptPreset] = [
        PromptPreset(
            id: UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000001")!,
            title: "Translate screen",
            prompt: "Translate what matters on this screen: its title, the main buttons, filters and prices. Skip repeated items."),
        PromptPreset(
            id: UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000002")!,
            title: "Where do I tap?",
            prompt: "Explain what this screen is for and tell me exactly where to tap for the most likely next step. Name the button and where it is on the screen."),
        PromptPreset(
            id: UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000003")!,
            title: "Is this a good deal?",
            prompt: "Look at the product, price and seller details on the screen. Say briefly whether it looks like a good deal and what I should double-check."),
    ]

    /// The saved presets, or the defaults until the user saves a list of their own (an empty list is kept as is).
    public var presets: [PromptPreset] {
        get {
            guard let data = defaults.data(forKey: key),
                  let saved = try? JSONDecoder().decode([PromptPreset].self, from: data)
            else { return Self.defaultPresets }
            return saved
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }
}
