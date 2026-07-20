# One Tap Transcribe

**Local, private push-to-talk dictation for macOS.** Hold a key, speak, release —
your words are transcribed on-device and inserted at the cursor in any app. Like
Wispr Flow, but every model runs on your Mac. Nothing leaves the machine.

- 🔒 **Fully on-device** — no accounts, no API keys, no network at inference.
- ⌨️ **Push-to-talk** — hold a modifier key, speak, release. Text pastes where your cursor is.
- 🧠 **Pluggable speech-to-text** — WhisperKit (OpenAI Whisper via Core ML) or Apple's built-in `SpeechTranscriber`.
- ✨ **Optional local cleanup** — tidy filler words / punctuation with Apple Foundation Models, Ollama, or any OpenAI-compatible server (MLX, LM Studio, llama.cpp). Fully editable prompt.
- 🌊 **Live overlay** — a floating waveform that shows partial text as you speak, then "Transcribing…".
- 🎛️ Everything configurable: trigger key, models, endpoints, prompts, appearance.

Menu-bar app (optional Dock icon). Built in Swift/SwiftUI. MIT-licensed.

## Requirements

- **macOS 26 (Tahoe) or later**, **Apple Silicon**. (Apple's on-device speech and
  LLM APIs are macOS 26+. WhisperKit itself runs on macOS 13+, but this build
  targets 26 for the built-in engines.)
- ~600 MB free disk for the default Whisper model (downloaded once, on first use).
- For the **Apple Foundation Models** cleanup option: Apple Intelligence enabled.

## Install

1. Download `OneTapTranscribe-x.y.z.dmg` from [Releases](https://github.com/jammastergirish/one-tap-transcribe/releases), open it, and drag
   **One Tap Transcribe** to Applications.
2. Launch it. A 🎙️ waveform icon appears in the menu bar (and the Dock).
3. Grant **Microphone** and **Accessibility** when prompted (or via
   Settings → Permissions). Accessibility is required for the global push-to-talk
   key and to paste into other apps.
4. On first dictation the Whisper model downloads (~600 MB) and caches under
   `~/Documents/huggingface`. After that it loads instantly.

**Hold Right ⌘, speak, release.** The text lands at your cursor.

> Verify a download (optional): `shasum -a 256 OneTapTranscribe-x.y.z.dmg` and
> compare against the checksum on the release page.

## Settings

Open from the menu-bar icon or main window → **Settings…**

- **General** — appearance (System/Light/Dark), push-to-talk key (Fn / Right-⌘ /
  Right-⌥ / Right-⌃), paste-vs-type, sounds, recording overlay + live text, menu-bar-only.
- **Speech-to-Text** — engine (WhisperKit or Apple), model, language, streaming.
- **Cleanup** — engine + endpoint/model, with a **Detect** button that lists the
  models installed on your machine. A warning shows if the chosen engine can't run.
- **Prompts** — edit the cleanup system prompt + user template (`{{text}}` = the transcript).
- **Permissions** — status and shortcuts to the relevant System Settings panes.

## Build from source

```bash
git clone <repo-url> && cd app
./build_app.sh release run     # compiles, bundles a signed .app, launches it
```

Requires Xcode 26 / Swift 6.3. `swift build` works for a quick compile, but the
`.app` bundle is needed for permissions and the menu-bar behavior.

**Optional (developers):** `./setup_signing.sh` creates a stable local self-signed
identity so rebuilds keep their macOS Accessibility grant (no re-granting after
every build). Without it the build falls back to ad-hoc signing.

## How it works

```
HotkeyManager ─▶ AudioRecorder ─▶ TranscriptionEngine ─▶ CleanupEngine ─▶ TextInjector
 (push-to-talk)  (16 kHz mono)     WhisperKitEngine        FoundationModelsEngine  (⌘V / type)
                  + waveform        AppleSpeechEngine        OllamaCleanup
                                                             OpenAICompatibleCleanup
                                                             (none)
```

`AppState` orchestrates the pipeline and publishes status to the menu bar and
overlay. Streaming (WhisperKit) transcribes as you speak using a confirmed-segment
sliding window, so only a short tail is decoded on release. Settings persist as
JSON in `UserDefaults`. New STT / cleanup back-ends only need to conform to a
protocol and be added to a factory.

## Privacy

Audio is captured, transcribed, and cleaned up entirely on your Mac. There are no
analytics, no accounts, and no network calls at inference time. The only network
use is the one-time Whisper model download from Hugging Face (skip it by using the
built-in Apple engine), and any local cleanup server *you* configure.

## Publishing (for maintainers)

For a download that opens without Gatekeeper warnings, the app must be signed with
an Apple **Developer ID Application** certificate (Apple Developer Program) and
**notarized**:

```bash
# 1. Build + sign with Developer ID (Hardened Runtime):
#    codesign --deep --options runtime --sign "Developer ID Application: …" OneTapTranscribe.app
# 2. Package:
./make_dmg.sh
# 3. Notarize + staple:
xcrun notarytool submit build/OneTapTranscribe-*.dmg --keychain-profile "NOTARY" --wait
xcrun stapler staple build/OneTapTranscribe-*.dmg
```

Then upload the `.dmg` (e.g. to GitHub Releases) and publish its SHA-256. Without
notarization, users must right-click → Open or clear the quarantine attribute.

## License

MIT — see [LICENSE](LICENSE). Copyright © 2026 Girish Gupta ·
[www.girishgupta.com](https://www.girishgupta.com).

Built with [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift), Apple's
`Speech` (SpeechAnalyzer) and `FoundationModels` frameworks.
