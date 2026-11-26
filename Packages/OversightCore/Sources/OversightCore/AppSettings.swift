import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system, en, ru

    /// `nil` means "follow the system language".
    public var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .en: return "en"
        case .ru: return "ru"
        }
    }
}

public final class AppSettings {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var provider: ProviderKind {
        get { defaults.string(forKey: "oversight.provider").flatMap(ProviderKind.init(rawValue:)) ?? .claude }
        set { defaults.set(newValue.rawValue, forKey: "oversight.provider") }
    }

    public var language: AppLanguage {
        get { defaults.string(forKey: "oversight.language").flatMap(AppLanguage.init(rawValue:)) ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "oversight.language") }
    }

    /// Instructions sent before every preset; blank restores the default.
    public var systemPrompt: String {
        get { defaults.string(forKey: "oversight.systemPrompt") ?? defaultSystemPrompt }
        set {
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                defaults.removeObject(forKey: "oversight.systemPrompt")
            } else {
                defaults.set(newValue, forKey: "oversight.systemPrompt")
            }
        }
    }

    /// The model the user typed for `kind`, or `nil` if none (blank counts as none).
    public func model(for kind: ProviderKind) -> String? {
        let value = defaults.string(forKey: "oversight.model.\(kind.rawValue)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    public func setModel(_ model: String, for kind: ProviderKind) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "oversight.model.\(kind.rawValue)"
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }

    /// The model to send requests with for the current provider.
    public var effectiveModel: String {
        model(for: provider) ?? provider.defaultModel
    }
}
