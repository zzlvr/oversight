import ReplayKit
import SwiftUI

struct HomeView: View {
    @ObservedObject var assistant: AssistantController
    @ObservedObject var settings: SettingsModel
    @ObservedObject var window: AnswerWindow

    var body: some View {
        Form {
            Section("Screen broadcast") {
                HStack(spacing: 14) {
                    BroadcastPicker().frame(width: 56, height: 56)
                    if assistant.receivingScreen {
                        Text("Receiving the screen")
                    } else {
                        Text("Tap the button and start the broadcast")
                    }
                }
                if assistant.listenerFailed {
                    Text("Cannot receive frames. Reopen the app").foregroundStyle(.red)
                }
            }

            Section("Floating window") {
                Button("Start floating window") { window.start() }
                AnswerLayerView(layer: window.displayLayer).frame(height: 110)
                if let failure = window.failure {
                    Text(verbatim: failure).foregroundStyle(.red)
                }
            }

            Section("Ask") {
                ForEach(Array(settings.presets.enumerated()), id: \.element.id) { index, preset in
                    Button {
                        Task { await assistant.ask(presetIndex: index) }
                    } label: {
                        Text(verbatim: "\(index + 1). \(preset.title)")
                    }
                    .disabled(assistant.thinking)
                }
            }

            if !assistant.answer.isEmpty {
                Section("Answer") {
                    Text(verbatim: assistant.answer).textSelection(.enabled)
                }
            }

            Section("Back Tap") {
                Text("In Shortcuts, create a shortcut with the action \"Ask about this screen\". Then assign it in Settings, Accessibility, Touch, Back Tap.")
                    .font(.footnote)
            }
        }
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
}

struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 56, height: 56))
        // Signing tools may rename bundle ids, so read the id of the embedded extension.
        let appex = Bundle.main.builtInPlugInsURL?.appendingPathComponent("OversightBroadcast.appex")
        picker.preferredExtension = appex.flatMap { Bundle(url: $0)?.bundleIdentifier }
        picker.showsMicrophoneButton = false
        // The system icon is dark; a light circle keeps it visible in dark mode.
        picker.backgroundColor = .white
        picker.layer.cornerRadius = 28
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
