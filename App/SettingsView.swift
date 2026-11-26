import SwiftUI
import OversightCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $model.provider) {
                    ForEach(ProviderKind.allCases, id: \.self) { kind in
                        Text(verbatim: kind.displayName).tag(kind)
                    }
                }
                SecureField("API key", text: $model.apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if model.keySaveFailed {
                    Text("Could not save the key").foregroundStyle(.red)
                }
                LabeledContent("Model") {
                    TextField(model.provider.defaultModel, text: $model.model)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Provider")
            } footer: {
                Text("Your key is stored in the iOS Keychain on this device only. Leave Model empty to use the inexpensive default.")
            }

            Section("Language") {
                Picker("Language", selection: $model.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        switch language {
                        case .system: Text("System").tag(language)
                        case .en: Text(verbatim: "English").tag(language)
                        case .ru: Text(verbatim: "Русский").tag(language)
                        }
                    }
                }
            }

            Section {
                NavigationLink("Prompt presets") { PresetsView(model: model) }
            } header: {
                Text("Prompts")
            } footer: {
                Text("The first preset is the one the floating window runs.")
            }

            Section("Instructions for the AI") {
                TextEditor(text: $model.systemPrompt).frame(minHeight: 140)
            }
        }
        .navigationTitle("Settings")
    }
}

struct PresetsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        List {
            ForEach($model.presets) { $preset in
                NavigationLink {
                    PresetEditor(preset: $preset)
                } label: {
                    Text(LocalizedStringKey(preset.title))
                }
            }
            .onDelete { model.presets.remove(atOffsets: $0) }
            .onMove { model.presets.move(fromOffsets: $0, toOffset: $1) }
        }
        .navigationTitle("Prompt presets")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button {
                    model.presets.append(PromptPreset(title: "New preset", prompt: ""))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add preset")
            }
        }
    }
}

struct PresetEditor: View {
    @Binding var preset: PromptPreset

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $preset.title)
            }
            Section("Prompt") {
                TextEditor(text: $preset.prompt).frame(minHeight: 160)
            }
        }
        .navigationTitle(preset.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
