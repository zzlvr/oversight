# Privacy

Oversight has no server of its own, no accounts and no analytics.

## What is sent

When you ask a question, the app sends one screenshot, your question or preset, and the instructions from Settings to the provider you selected (Anthropic, OpenAI or Google). That provider's terms and data policy apply. Nothing is sent until you ask.

A screenshot contains whatever is on the screen, including messages, addresses or payment details. Do not ask while such information is visible.

## What stays on the phone

- While the broadcast runs, the screen recording extension passes frames to the app over the phone's internal loopback connection. Before sending, the extension checks that the receiver holds the key it saw the first time.
- The app keeps the latest frame and up to six recent screens in memory so you can ask about them. They are not written to disk, and they are cleared when the app receives the end of the broadcast or is closed.
- API keys are stored in the iOS Keychain.
- Presets, instructions and settings are stored in the app's preferences.
