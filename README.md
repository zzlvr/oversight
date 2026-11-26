# Oversight

Oversight is an iPhone app that helps you use apps in a language you do not read. It looks at your screen when you ask, sends that one screenshot to the AI provider you choose, and shows the answer in a small floating window on top of the other app.

I built it to shop in a Chinese app without taking screenshots and switching to a chat every time.

## Features

- Answers in a Picture-in-Picture window over other apps
- Your own questions about a screen you marked, plus editable prompt presets
- Claude, OpenAI or Gemini with your own API key
- Inexpensive models by default, any model name can be entered in Settings
- English and Russian interface

## Requirements

- iPhone with iOS 18 or later
- An API key from Anthropic, OpenAI or Google
- A computer with Sideloadly or AltStore to install the app

Oversight is not on the App Store.

## Install

1. Download `Oversight.ipa` from the Releases page.
2. Open it in [Sideloadly](https://sideloadly.io), connect your iPhone, sign in with your Apple ID and start.
3. On the iPhone, turn on Developer Mode (Settings, Privacy & Security) and trust your profile (Settings, General, VPN & Device Management).

With a free Apple ID the signature lasts 7 days. Install the app again after that.

## Use

1. Open Settings in the app and add your API key.
2. Tap the red button and start the screen broadcast.
3. Open the floating window.
4. Switch to the other app.
   - Pause in the floating window runs your first preset.
   - The skip buttons turn pages of a long answer.
5. To ask something specific, tap the return button in the floating window and type your question about that screen.

## Limits

- iOS does not let apps draw over other apps, so Oversight cannot highlight buttons. It describes where to tap.
- The screen broadcast has to be running, and iOS shows its recording indicator.
- Apps that block screen capture give a black picture.
- The floating window covers part of the screen and is part of the screenshot.

## How it works

See [docs/architecture.md](docs/architecture.md). What leaves your phone is described in [PRIVACY.md](PRIVACY.md).

## Build

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen
swift test --package-path Packages/OversightCore
```

GitHub Actions runs the tests and builds an unsigned `.ipa` on every push.

## License

MIT, see [LICENSE](LICENSE).
