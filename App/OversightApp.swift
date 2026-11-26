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
        // iOS saves a picture of the app for the app switcher; recent screens must not be in it.
        .overlay {
            if scenePhase != .active {
                ZStack {
                    Color(.systemBackground)
                    Text(verbatim: "Oversight").font(.title.bold())
                }
                .ignoresSafeArea()
            }
        }
        .fontDesign(.rounded)
        .environment(\.locale, settings.locale)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { assistant.appBecameActive() }
        }
    }
}
