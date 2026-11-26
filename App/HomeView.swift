import ReplayKit
import SwiftUI
import OversightCore

struct HomeView: View {
    @ObservedObject var assistant: AssistantController
    @ObservedObject var settings: SettingsModel
    @ObservedObject var window: AnswerWindow
    @State private var question = ""
    @FocusState private var typing: Bool

    private var hasKey: Bool {
        !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            setupSection
            screenSection
            if assistant.thinking || !assistant.answer.isEmpty {
                answerSection
            }
            helpSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Oversight")
        .toolbar {
            NavigationLink {
                SettingsView(model: settings)
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        .onAppear {
            assistant.startListening()
            window.prepare()
        }
    }

    private var setupSection: some View {
        Section("Get ready") {
            NavigationLink {
                SettingsView(model: settings)
            } label: {
                step(done: hasKey, title: "API key", detail: hasKey ? "Saved" : "Tap to add your key")
            }

            HStack {
                step(done: assistant.receivingScreen, title: "Screen broadcast",
                     detail: assistant.receivingScreen ? "Receiving the screen" : "Tap the red button to start")
                Spacer()
                BroadcastPicker().frame(width: 48, height: 48)
            }
            if assistant.listenerFailed {
                Text("Cannot receive frames. Reopen the app").foregroundStyle(.red)
            }

            HStack {
                step(done: window.isActive, title: "Floating window",
                     detail: window.isActive ? "Open" : "Answers appear in it")
                Spacer()
                Button("Open") { window.start() }
                    .buttonStyle(.borderedProminent)
                    .disabled(window.isActive)
            }
            // The window is rendered from this layer, so it has to stay on screen.
            AnswerLayerView(layer: window.displayLayer)
                .frame(height: 72)
                .listRowInsets(EdgeInsets())
            if let failure = window.failure {
                Text(verbatim: failure).foregroundStyle(.red)
            }
        }
    }

    private func step(done: Bool, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var screenSection: some View {
        Section("Ask about a screen") {
            if assistant.screens.isEmpty {
                Text("Open the app you need help with, wait a few seconds, then come back here.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(assistant.screens) { screen in
                            thumbnail(screen)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(alignment: .bottom) {
                TextField("What do you want to know?", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($typing)
                Button {
                    let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
                    question = ""
                    typing = false
                    Task { await assistant.askAboutSelectedScreen(asked) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Send")
                .disabled(!canAsk || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(settings.presets) { preset in
                Button {
                    typing = false
                    Task { await assistant.askAboutSelectedScreen(preset.prompt) }
                } label: {
                    Text(LocalizedStringKey(preset.title))
                }
                .disabled(!canAsk)
            }
        }
    }

    private var canAsk: Bool {
        !assistant.thinking && assistant.selectedScreen != nil
    }

    private func thumbnail(_ screen: CapturedScreen) -> some View {
        let selected = screen.id == assistant.selectedScreenID
        return Button {
            assistant.selectedScreenID = screen.id
        } label: {
            Image(uiImage: UIImage(data: screen.jpeg) ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(screen.date, style: .time))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var answerSection: some View {
        Section("Answer") {
            if assistant.thinking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Thinking…")
                }
            } else {
                Text(verbatim: assistant.answer).textSelection(.enabled)
            }
        }
    }

    private var helpSection: some View {
        Section("While you are in another app") {
            Label("Pause in the floating window runs your first preset", systemImage: "pause.fill")
            Label("The skip buttons turn pages of a long answer", systemImage: "goforward")
        }
        .font(.footnote)
    }
}

struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        // Signing tools may rename bundle ids, so read the id of the embedded extension.
        let appex = Bundle.main.builtInPlugInsURL?.appendingPathComponent("OversightBroadcast.appex")
        picker.preferredExtension = appex.flatMap { Bundle(url: $0)?.bundleIdentifier }
        picker.showsMicrophoneButton = false
        // The system icon is dark; a light circle keeps it visible in dark mode.
        picker.backgroundColor = .white
        picker.layer.cornerRadius = 24
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
