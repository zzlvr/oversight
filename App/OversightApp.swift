import SwiftUI

@main
struct OversightApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SettingsView(model: model)
            }
            .environment(\.locale, model.locale)
        }
    }
}
