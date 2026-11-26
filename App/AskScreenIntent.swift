import AppIntents

/// The action to assign to Back Tap through the Shortcuts app.
struct AskScreenIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask about this screen"
    static var description = IntentDescription("Sends the current screen to your AI with one of your prompt presets.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Preset number", default: 1)
    var presetNumber: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Ask about this screen with preset \(\.$presetNumber)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await AssistantController.shared.ask(presetIndex: presetNumber - 1)
        return .result()
    }
}

struct OversightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskScreenIntent(),
            phrases: ["Ask \(.applicationName) about this screen"],
            shortTitle: "Ask about screen",
            systemImageName: "viewfinder")
    }
}
