import SwiftUI
import OversightCore

/// Owns the frame listener, the floating window and the requests to the AI.
@MainActor
final class AssistantController: ObservableObject {
    static let shared = AssistantController()

    let settings = SettingsModel()
    let window = AnswerWindow()

    @Published var listenerFailed = false
    @Published var receivingScreen = false
    @Published var answer = ""
    @Published var thinking = false

    private let frames = FrameBuffer()
    private let receiver = FrameReceiver(identity: .load(from: KeychainStore(service: "com.zzlvr.oversight")))
    private var listening = false

    private init() {
        window.onPlayPause = { [weak self] in
            Task { @MainActor in await self?.ask(presetIndex: 0) }
        }
    }

    func startListening() {
        guard !listening else { return }
        listening = true
        let frames = frames
        receiver.start(
            onState: { [weak self] state in
                Task { @MainActor in
                    if case .failed = state {
                        self?.listening = false
                        self?.listenerFailed = true
                    } else {
                        self?.listenerFailed = false
                    }
                }
            },
            onFrame: { [weak self] data in
                frames.store(data)
                Task { @MainActor in self?.receivingScreen = true }
            },
            onEnd: { [weak self] in
                frames.clear()
                Task { @MainActor in self?.receivingScreen = false }
            })
    }

    func ask(presetIndex: Int) async {
        startListening()
        guard !thinking else { return }
        let presets = settings.presets
        guard presets.indices.contains(presetIndex) else {
            present(text("No prompt preset with that number"))
            return
        }
        thinking = true
        defer { thinking = false }
        window.show(text("Thinking…"))

        let stored = AppSettings()
        let kind = stored.provider
        let prompt = composePrompt(
            system: stored.systemPrompt,
            preset: presets[presetIndex].prompt,
            answerLanguage: answerLanguageName(for: stored.language))
        let service = AnswerService(provider: provider(for: kind))
        do {
            let reply = try await service.ask(
                prompt: prompt,
                frame: frames.latest(),
                apiKey: KeychainStore(service: "com.zzlvr.oversight").get(kind.rawValue),
                model: stored.effectiveModel)
            present(reply)
        } catch let error as AssistError {
            var message = text(error.messageKey)
            if case .http(let status, let detail) = error, status != 0 {
                message += "\n\(status): \(detail)"
            }
            present(message)
        } catch {
            present(error.localizedDescription)
        }
    }

    private func present(_ message: String) {
        answer = message
        window.show(message)
    }

    /// Looks a string up in the language chosen inside the app.
    private func text(_ key: String) -> String {
        if let code = settings.language.localeIdentifier {
            guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
                  let bundle = Bundle(path: path)
            else { return key }
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
