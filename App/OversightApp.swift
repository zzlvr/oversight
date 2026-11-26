import SwiftUI

@main
struct OversightApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(assistant: .shared, settings: AssistantController.shared.settings)
        }
    }
}

struct RootView: View {
    @ObservedObject var assistant: AssistantController
    @ObservedObject var settings: SettingsModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            HomeView(assistant: assistant, settings: settings, window: assistant.window)
        }
        .environment(\.locale, settings.locale)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { assistant.startListening() }
        }
    }
}
