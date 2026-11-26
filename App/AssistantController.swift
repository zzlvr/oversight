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
    private let recent = RecentFrames()
    nonisolated private static let senderKey = "pinnedBroadcastKey"
    private let receiver = FrameReceiver(
        identity: .load(from: KeychainStore(service: "com.zzlvr.oversight")),
        senders: PinStore(
            load: { UserDefaults.standard.data(forKey: AssistantController.senderKey) },
            save: { UserDefaults.standard.set($0, forKey: AssistantController.senderKey) }))
    private var listening = false

    private init() {
        window.onPlayPause = { [weak self] in
            Task { @MainActor in await self?.askFromWindow() }
        }
        window.onSave = { [weak self] in
            Task { @MainActor in self?.saveCurrentScreen() }
        }
        window.onReturn = { [weak self] pressed in
            Task { @MainActor in self?.markScreen(leftAt: pressed) }
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

    /// Forgets which screen broadcast the app trusts; the next one to connect is remembered.
    func resetPairing() {
        UserDefaults.standard.removeObject(forKey: Self.senderKey)
    }

    func appBecameActive() {
        startListening()
    }

    /// The window's skip-back button: keep the screen of the other app without asking anything.
    private func saveCurrentScreen() {
        guard UIApplication.shared.applicationState != .active, !thinking else { return }
        guard let frame = frames.latest() else {
            window.show(text("No screen captured yet. Start the broadcast"))
            return
        }
        mark(frame)
        window.show(text("Screen saved. Open Oversight to ask about it"))
    }

    /// The window's full-screen button: keep what was on screen just before it was pressed.
    private func markScreen(leftAt pressed: Date) {
        guard let frame = recent.frame(before: pressed.addingTimeInterval(-0.7)) else { return }
        mark(frame)
    }

    private func mark(_ frame: Data) {
        history.mark(frame)
        screens = history.screens
        selectedScreenID = screens.last?.id
    }

    private func received(_ data: Data) {
        receivingScreen = true
        // While Oversight itself is on screen the frames show Oversight, so they are not kept.
        if UIApplication.shared.applicationState != .active {
            recent.add(data)
        }
    }

    private func broadcastEnded() {
        receivingScreen = false
        history.clear()
        recent.clear()
        screens = []
        selectedScreenID = nil
    }

    /// The window's button: the live screen in another app, or the selected one inside Oversight.
    private func askFromWindow() async {
        let inOversight = UIApplication.shared.applicationState == .active
        let frame = inOversight ? selectedScreen?.jpeg : frames.latest()
        // A screen asked about from another app stays available for follow-up questions.
        if !inOversight, let frame { mark(frame) }
        guard let preset = settings.presets.first else {
            present(text("No prompt presets. Add one in Settings"))
            return
        }
        await ask(preset.prompt, frame: frame)
    }

    func askAboutSelectedScreen(_ prompt: String) async {
        await ask(prompt, frame: selectedScreen?.jpeg)
    }

    private func ask(_ text: String, frame: Data?) async {
        guard !thinking else { return }
        guard let question = cleanedQuestion(text) else {
            present(self.text("This preset has no text. Edit it in Settings"))
            return
        }
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
            if case .http(let status, let detail) = error, let shown = errorDetail(status: status, message: detail) {
                message += "\n\(shown)"
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
