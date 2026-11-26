import SwiftUI
import UIKit
import OversightCore

/// Owns the frame listener, the floating window and the requests to the AI.
@MainActor
final class AssistantController: ObservableObject {
    static let shared = AssistantController()

    let settings = SettingsModel()
    let window = AnswerWindow()

    @Published var listenerFailed = false
    @Published var receivingScreen = false
    @Published var screens: [CapturedScreen] = []
    @Published var selectedScreenID: UUID?
    @Published var answer = ""
    @Published var thinking = false

    private let frames = FrameBuffer()
    private let history = ScreenHistory()
    private let receiver = FrameReceiver(identity: .load(from: KeychainStore(service: "com.zzlvr.oversight")))
    private var listening = false

    private init() {
        window.onPlayPause = { [weak self] in
            Task { @MainActor in await self?.askFromWindow() }
        }
    }

    var selectedScreen: CapturedScreen? {
        screens.first { $0.id == selectedScreenID }
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
                Task { @MainActor in self?.received(data) }
            },
            onEnd: { [weak self] in
                frames.clear()
                Task { @MainActor in self?.broadcastEnded() }
            })
    }

    /// Offers the screens seen in other apps, preselecting the one from just before the switch.
    func appBecameActive() {
        startListening()
        screens = history.screens
        selectedScreenID = history.screen(before: Date().addingTimeInterval(-1.5))?.id
    }

    private func received(_ data: Data) {
        receivingScreen = true
        // While Oversight itself is on screen the frames show Oversight, so they are not kept.
        if UIApplication.shared.applicationState != .active {
            history.add(data)
        }
    }

    private func broadcastEnded() {
        receivingScreen = false
        history.clear()
        screens = []
        selectedScreenID = nil
    }

    /// The window's button: the live screen in another app, or the selected one inside Oversight.
    private func askFromWindow() async {
        let frame = UIApplication.shared.applicationState == .active ? selectedScreen?.jpeg : frames.latest()
        guard let preset = settings.presets.first else {
            present(text("No prompt presets. Add one in Settings"))
            return
        }
        await ask(preset.prompt, frame: frame)
    }

    func askAboutSelectedScreen(_ prompt: String) async {
        await ask(prompt, frame: selectedScreen?.jpeg)
    }

    private func ask(_ question: String, frame: Data?) async {
        guard !thinking else { return }
        thinking = true
        defer { thinking = false }
        window.show(text("Thinking…"))

        let stored = AppSettings()
        let kind = stored.provider
        let prompt = composePrompt(
            system: stored.systemPrompt,
            preset: question,
            answerLanguage: answerLanguageName(for: stored.language))
        let service = AnswerService(provider: provider(for: kind))
        do {
            let reply = try await service.ask(
                prompt: prompt,
                frame: frame,
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
