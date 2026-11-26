import ReplayKit
import SwiftUI
import UIKit
import OversightCore

struct HomeView: View {
    @ObservedObject var assistant: AssistantController
    @ObservedObject var settings: SettingsModel
    @ObservedObject var window: AnswerWindow
    @AppStorage("oversight.welcomed") private var welcomed = false
    @State private var question = ""
    @FocusState private var typing: Bool

    private var hasKey: Bool {
        !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var ready: Bool {
        hasKey && assistant.receivingScreen && window.isActive
    }

    private var canAsk: Bool {
        !assistant.thinking && assistant.selectedScreen != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                setupCard
                if assistant.thinking || !assistant.answer.isEmpty {
                    answerCard
                }
                screenCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
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
        .sheet(isPresented: Binding(get: { !welcomed }, set: { welcomed = !$0 })) {
            WelcomeView { welcomed = true }
                .environment(\.locale, settings.locale)
        }
    }

    // MARK: Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if ready {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Color.accentColor)
                Text("Open any app and press pause in the floating window.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Get set up").font(.title3.bold())

                NavigationLink {
                    SettingsView(model: settings)
                } label: {
                    HStack {
                        step(done: hasKey, title: "API key", detail: hasKey ? "Saved" : "Tap to add your key")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                HStack {
                    step(done: assistant.receivingScreen, title: "Screen broadcast",
                         detail: assistant.receivingScreen ? "Receiving the screen" : "Tap the red button to start")
                    Spacer()
                    BroadcastPicker().frame(width: 44, height: 44)
                }

                Divider()
                HStack {
                    step(done: window.isActive, title: "Floating window",
                         detail: window.isActive ? "Open" : "Answers appear in it")
                    Spacer()
                    Button { window.start() } label: {
                        Text("Open").foregroundStyle(Color(.systemBackground))
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(window.isActive)
                }
            }

            if assistant.listenerFailed {
                Text("Cannot receive frames. Reopen the app").foregroundStyle(.red)
            }
            if let failure = window.failure {
                Text(verbatim: failure).foregroundStyle(.red)
            }
            // The floating window is rendered from this layer, so it has to stay on screen.
            AnswerLayerView(layer: window.displayLayer)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        }
        .card()
    }

    private func step(done: Bool, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.accentColor : Color.secondary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Screen

    private var screenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen").font(.title3.bold())

            if let selected = assistant.selectedScreen {
                image(selected)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxHeight: 340)
                    .padding(10)
                    .overlay(ViewfinderCorners().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round)))
                    .frame(maxWidth: .infinity)
            } else {
                Text("In another app, press −10 in the floating window to save the screen, or pause to ask right away. It appears here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .overlay(ViewfinderCorners().stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round)))
            }

            if assistant.screens.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(assistant.screens) { screen in
                            thumbnail(screen)
                        }
                    }
                    .padding(3)
                }
            }
        }
        .card()
    }

    private func image(_ screen: CapturedScreen) -> Image {
        Image(uiImage: UIImage(data: screen.jpeg) ?? UIImage())
    }

    private func thumbnail(_ screen: CapturedScreen) -> some View {
        let selected = screen.id == assistant.selectedScreenID
        return Button {
            assistant.selectedScreenID = screen.id
        } label: {
            image(screen)
                .resizable()
                .scaledToFit()
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3))
                .opacity(selected ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(screen.date, style: .time))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Answer

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Answer").font(.title3.bold())
                Spacer()
                if !assistant.thinking {
                    Button {
                        UIPasteboard.general.string = assistant.answer
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel("Copy")
                }
            }
            if assistant.thinking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Thinking…").foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: assistant.answer)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
        .card()
    }

    // MARK: Composer

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(settings.presets) { preset in
                        Button {
                            typing = false
                            Task { await assistant.askAboutSelectedScreen(preset.prompt) }
                        } label: {
                            Text(LocalizedStringKey(preset.title)).font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .disabled(!canAsk)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about this screen", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($typing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                Button {
                    let asked = trimmedQuestion
                    question = ""
                    typing = false
                    Task { await assistant.askAboutSelectedScreen(asked) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                }
                .accessibilityLabel("Send")
                .disabled(!canAsk || trimmedQuestion.isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

/// Four corner brackets, like a camera viewfinder.
struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.14
        let r = rect.insetBy(dx: 2, dy: 2)
        var path = Path()
        for (x, dx) in [(r.minX, length), (r.maxX, -length)] {
            for (y, dy) in [(r.minY, length), (r.maxY, -length)] {
                path.move(to: CGPoint(x: x + dx, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy))
            }
        }
        return path
    }
}

struct WelcomeView: View {
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to Oversight").font(.largeTitle.bold())
                Text("Help with any app, in your language").foregroundStyle(.secondary)
            }
            row("key", "Add your API key. Gemini has a free tier.")
            row("record.circle", "Start the screen broadcast. Nothing is sent until you ask.")
            row("pip", "Open the floating window and switch to any app.")
            Spacer()
            Text("When you ask, one screenshot goes to the AI provider you chose.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(action: done) {
                Text("Continue").font(.headline).foregroundStyle(Color(.systemBackground)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .fontDesign(.rounded)
    }

    private func row(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 28)
            Text(text)
        }
    }
}

struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        // Signing tools may rename bundle ids, so read the id of the embedded extension.
        let appex = Bundle.main.builtInPlugInsURL?.appendingPathComponent("OversightBroadcast.appex")
        picker.preferredExtension = appex.flatMap { Bundle(url: $0)?.bundleIdentifier }
        picker.showsMicrophoneButton = false
        // The system icon takes its colour from the surroundings, so draw our own red record button.
        let symbol = UIImage(
            systemName: "record.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 36))?
            .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        for case let button as UIButton in picker.subviews {
            button.setImage(symbol, for: .normal)
            button.frame = picker.bounds
            button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
