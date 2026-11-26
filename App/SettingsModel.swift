import SwiftUI
import OversightCore

@MainActor
final class SettingsModel: ObservableObject {
    private let settings: AppSettings
    private let presetStore: PresetStore
    private let keychain: KeychainStore
    private var loading = false

    @Published var provider: ProviderKind {
        didSet {
            guard provider != oldValue else { return }
            settings.provider = provider
            loading = true
            apiKey = keychain.get(provider.rawValue) ?? ""
            model = settings.model(for: provider) ?? ""
            loading = false
        }
    }

    @Published var apiKey: String {
        didSet {
            guard !loading else { return }
            saveKey()
        }
    }

    @Published var model: String {
        didSet {
            guard !loading else { return }
            settings.setModel(model, for: provider)
        }
    }

    @Published var language: AppLanguage {
        didSet { settings.language = language }
    }

    @Published var systemPrompt: String {
        didSet { settings.systemPrompt = systemPrompt }
    }

    @Published var presets: [PromptPreset] {
        didSet { presetStore.presets = presets }
    }

    @Published var keySaveFailed = false

    init() {
        let settings = AppSettings()
        let presetStore = PresetStore()
        let keychain = KeychainStore(service: "com.zzlvr.oversight")
        self.settings = settings
        self.presetStore = presetStore
        self.keychain = keychain
        provider = settings.provider
        apiKey = keychain.get(settings.provider.rawValue) ?? ""
        model = settings.model(for: settings.provider) ?? ""
        language = settings.language
        systemPrompt = settings.systemPrompt
        presets = presetStore.presets
    }

    var locale: Locale {
        language.localeIdentifier.map(Locale.init(identifier:)) ?? .current
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychain.remove(provider.rawValue)
            keySaveFailed = false
        } else {
            do {
                try keychain.set(trimmed, for: provider.rawValue)
                keySaveFailed = false
            } catch {
                keySaveFailed = true
            }
        }
    }
}

extension ProviderKind {
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        }
    }
}
