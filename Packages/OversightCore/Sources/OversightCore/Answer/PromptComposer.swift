import Foundation

public let defaultSystemPrompt = """
The image is a screenshot of the user's iPhone. It may show an app in a foreign language. \
A small floating window with white text on black may be visible: it belongs to the assistant itself, ignore it. \
Reply in plain text without Markdown, under 300 characters unless asked for more, most important first. \
Do not list everything on the screen. When you name a button, quote its label and say where it is.
"""

public func composePrompt(system: String, preset: String, answerLanguage: String) -> String {
    "\(system)\nAnswer in \(answerLanguage).\n\n\(preset)"
}

public func answerLanguageName(for language: AppLanguage, preferred: [String] = Locale.preferredLanguages) -> String {
    let code = language.localeIdentifier ?? preferred.first ?? "en"
    let languageCode = String(code.prefix { $0 != "-" && $0 != "_" })
    return Locale(identifier: "en").localizedString(forLanguageCode: languageCode) ?? "English"
}
