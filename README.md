# OneTap Transcribe

A tiny, fully-local push-to-talk dictation app for Apple Silicon — like Wispr
Flow, but every model runs on your Mac. Hold a key, speak, release, and the
transcribed (and optionally cleaned-up) text is pasted wherever your cursor is.

- **Speech-to-text (local):** WhisperKit (OpenAI Whisper via Core ML) *or*
  Apple's built-in `SpeechTranscriber` — switchable in Settings.
- **Cleanup (local):** Apple Foundation Models (on-device), Ollama, or any
  OpenAI-compatible server (MLX `mlx_lm.server`, LM Studio, llama.cpp, vLLM),
  driven by a fully editable prompt. Or none.
- **Everything configurable:** trigger key, models, endpoints, and prompts.
- Menu-bar only. No Dock icon. Nothing leaves your machine.

Requires **macOS 26+** and **Apple Silicon** (Apple's on-device STT and LLM are
macOS 26 APIs). Built with Swift 6.3 / Xcode 26.

## Build & run

```bash
./build_app.sh release run
```

This compiles the app, wraps it into `build/OneTapTranscribe.app` (so macOS will
grant it permissions and hide it from the Dock), ad-hoc signs it, and launches
it. To just build without launching: `./build_app.sh release`.

For fast iteration during development you can also `swift run`, but permissions
and the menu-bar-only behavior only work correctly from the `.app` bundle.

## First run

1. A 🎙️ icon appears in the menu bar.
2. Grant **Microphone** and **Accessibility** when prompted (or from the
   Permissions tab in Settings → *Open Settings*). Accessibility is required for
   the global hotkey and for pasting into other apps.
3. If using WhisperKit, the first dictation downloads the model (~600 MB for the
   default `large-v3`), cached under Application Support afterwards.
4. Hold the push-to-talk key (default **Right ⌘**), speak, release. The text is
   inserted at your cursor.

## Settings

Open from the menu-bar icon → **Settings…**

- **General** — push-to-talk key (Fn / Right-⌘ / Right-⌥ / Right-⌃), paste-vs-type,
  start/stop sounds.
- **Speech-to-Text** — engine (WhisperKit or Apple), model, language/locale.
- **Cleanup** — engine + endpoint/model, with a **Detect** button that lists the
  models actually installed on your machine (Ollama tags / `/v1/models`).
- **Prompts** — edit the cleanup system prompt and user template. `{{text}}` is
  replaced with the raw transcript.
- **Permissions** — status and shortcuts to the relevant System Settings panes.

## Notes / gotchas

- **Fn key**: macOS grabs Fn for dictation/emoji by default. To use it here, set
  *System Settings → Keyboard → "Press 🌐 key to" → Do Nothing*. Right-⌘ avoids
  this entirely and is the default.
- **Apple Foundation Models cleanup** needs Apple Intelligence enabled
  (*System Settings → Apple Intelligence & Siri*).
- **Ad-hoc signing** means macOS may re-prompt for Accessibility after a rebuild.
  Keep the built `.app` and relaunch it, or set up a self-signed identity.

## Architecture

Pluggable back-ends behind two protocols, so new engines are easy to add:

```
HotkeyManager ──► AudioRecorder ──► TranscriptionEngine ──► CleanupEngine ──► TextInjector
 (push-to-talk)   (16 kHz mono)      WhisperKitEngine        FoundationModelsEngine   (⌘V / type)
                                     AppleSpeechEngine        OllamaCleanup
                                                              OpenAICompatibleCleanup
                                                              PassthroughCleanup
```

`AppState` orchestrates the pipeline and publishes status to the menu bar;
`SettingsStore` persists `AppSettings` (JSON in UserDefaults).
