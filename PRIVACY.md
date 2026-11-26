# Privacy

Oversight has no server of its own, no accounts and no analytics.

## What is sent

When you ask a question, the app sends one screenshot, your question or preset, and the instructions from Settings to the provider you selected (Anthropic, OpenAI or Google). That provider's terms and data policy apply. Nothing is sent until you ask.

On the free tier of the Gemini API, which is the default provider, Google may use what you send to improve its products and human reviewers may read it. See the [Gemini API terms](https://ai.google.dev/gemini-api/terms), which also set age and regional conditions.

A screenshot contains whatever is on the screen, including messages, addresses or payment details. Do not ask while such information is visible.

## What stays on the phone

- While the broadcast runs, the screen recording extension passes frames to the app over the phone's internal loopback connection. Before sending, the extension checks that the receiver holds the key it saw the first time.
- The app keeps the latest frame, a few seconds of recent frames and up to six screens you marked (with the window's pause, skip-back or full-screen button) in memory so you can ask about them. The app does not save them to files, and they are cleared when the app receives the end of the broadcast or is closed.
- When you leave Oversight, iOS saves a picture of it for the app switcher. That picture can include the screens and the answer shown in the app.
- API keys are stored in the iOS Keychain.
- Presets, instructions and settings are stored in the app's preferences.
