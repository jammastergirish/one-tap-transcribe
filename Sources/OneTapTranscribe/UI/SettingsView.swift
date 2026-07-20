import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            SpeechTab().tabItem { Label("Speech-to-Text", systemImage: "waveform") }
            CleanupTab().tabItem { Label("Cleanup", systemImage: "sparkles") }
            PromptsTab().tabItem { Label("Prompts", systemImage: "text.alignleft") }
            PermissionsTab().tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding(20)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Picker("Push-to-talk key", selection: $store.settings.triggerKey) {
                ForEach(TriggerKey.allCases) { key in
                    Text(key.displayName).tag(key)
                }
            }
            if store.settings.triggerKey == .fn {
                Text("Set System Settings → Keyboard → “Press 🌐 key to” → Do Nothing, or Fn will also trigger macOS dictation.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Insert text by pasting (⌘V)", isOn: $store.settings.pasteInsteadOfType)
            Text(store.settings.pasteInsteadOfType
                 ? "Fast and reliable. Briefly uses the clipboard, then restores it."
                 : "Types each character. No clipboard use, but slower.")
                .font(.caption).foregroundStyle(.secondary)

            Toggle("Play start/stop sounds", isOn: $store.settings.playFeedbackSounds)

            Divider()

            Toggle("Show recording overlay", isOn: $store.settings.showOverlay)
            HStack(alignment: .top) {
                Text("A floating waveform at the bottom-center of the screen while dictating, then “Transcribing…”.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Preview") { state.previewOverlay() }
            }

            Divider()

            Toggle("Menu-bar only (hide Dock icon)", isOn: $store.settings.menuBarOnly)
            Text("Off shows a Dock icon and main window — easier to find. Turn on once you're comfortable using just the menu-bar icon.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Speech-to-Text

private struct SpeechTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Picker("Engine", selection: $store.settings.sttEngine) {
                ForEach(STTEngineKind.allCases) { Text($0.displayName).tag($0) }
            }

            switch store.settings.sttEngine {
            case .whisperKit:
                Picker("Model", selection: $store.settings.whisperModel) {
                    ForEach(WhisperModel.allCases) { Text($0.displayName).tag($0) }
                }
                TextField("Language (e.g. en, es, or auto)", text: $store.settings.whisperLanguage)
                Text("Models download from Hugging Face on first use and are cached on disk.")
                    .font(.caption).foregroundStyle(.secondary)

            case .appleSpeech:
                TextField("Locale (e.g. en-US)", text: $store.settings.appleSpeechLocale)
                Text("Uses Apple's built-in on-device model. The locale asset downloads once, then runs fully offline.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Cleanup

private struct CleanupTab: View {
    @EnvironmentObject var store: SettingsStore

    @State private var detected: [String] = []
    @State private var availability: String = ""
    @State private var isChecking = false

    var body: some View {
        Form {
            Picker("Cleanup engine", selection: $store.settings.cleanup) {
                ForEach(CleanupKind.allCases) { Text($0.displayName).tag($0) }
            }

            switch store.settings.cleanup {
            case .none:
                Text("Text is inserted exactly as transcribed.")
                    .font(.caption).foregroundStyle(.secondary)

            case .appleFoundation:
                Text("Runs on Apple's on-device model. Requires Apple Intelligence to be enabled.")
                    .font(.caption).foregroundStyle(.secondary)

            case .ollama:
                TextField("Endpoint", text: $store.settings.ollamaEndpoint)
                modelField(binding: $store.settings.ollamaModel, placeholder: "e.g. llama3.2, qwen2.5")

            case .openAICompatible:
                TextField("Endpoint", text: $store.settings.openAIEndpoint)
                SecureField("API key (blank for local servers)", text: $store.settings.openAIAPIKey)
                modelField(binding: $store.settings.openAIModel, placeholder: "model id")
                Text("For MLX: run `mlx_lm.server --port 8080`. Also works with LM Studio, llama.cpp, vLLM.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !availability.isEmpty {
                Divider()
                Label(availability, systemImage: availability.hasPrefix("Ready")
                      ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(availability.hasPrefix("Ready") ? .green : .orange)
            }
        }
        .padding(.top, 8)
        .task(id: cleanupSignature) { await check() }
    }

    @ViewBuilder
    private func modelField(binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            TextField(placeholder, text: binding)
            if !detected.isEmpty {
                Menu("Detected") {
                    ForEach(detected, id: \.self) { m in
                        Button(m) { binding.wrappedValue = m }
                    }
                }
                .frame(width: 110)
            }
            Button {
                Task { await check() }
            } label: {
                if isChecking { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    private var cleanupSignature: String {
        "\(store.settings.cleanup.rawValue)|\(store.settings.ollamaEndpoint)|\(store.settings.openAIEndpoint)"
    }

    private func check() async {
        isChecking = true
        defer { isChecking = false }
        let s = store.settings
        switch s.cleanup {
        case .none:
            detected = []; availability = ""
        case .appleFoundation:
            let engine = FoundationModelsEngine()
            availability = format(await engine.availability())
            detected = []
        case .ollama:
            let models = await SystemDetector.ollamaModels(endpoint: s.ollamaEndpoint)
            detected = models ?? []
            availability = format(await OllamaCleanup(endpoint: s.ollamaEndpoint, model: s.ollamaModel).availability())
        case .openAICompatible:
            let models = await SystemDetector.openAIModels(endpoint: s.openAIEndpoint, apiKey: s.openAIAPIKey)
            detected = models ?? []
            availability = format(await OpenAICompatibleCleanup(
                endpoint: s.openAIEndpoint, model: s.openAIModel, apiKey: s.openAIAPIKey).availability())
        }
    }

    private func format(_ a: CleanupAvailability) -> String {
        switch a {
        case .available:            return "Ready"
        case .unavailable(let why): return why
        }
    }
}

// MARK: - Prompts

private struct PromptsTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cleanup system prompt").font(.headline)
                Spacer()
                Button("Reset") { store.settings.cleanupSystemPrompt = DefaultPrompts.cleanupSystem }
            }
            TextEditor(text: $store.settings.cleanupSystemPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Text("User message template").font(.headline)
                Spacer()
                Button("Reset") { store.settings.cleanupUserTemplate = DefaultPrompts.cleanupUserTemplate }
            }
            TextEditor(text: $store.settings.cleanupUserTemplate)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 70)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            Text("`{{text}}` is replaced with the raw transcript. These prompts are sent to whichever cleanup engine is selected.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Permissions

private struct PermissionsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            permissionRow(
                title: "Microphone",
                granted: state.micAuthorized,
                detail: "Needed to record your voice.",
                openAction: Permissions.openMicrophoneSettings
            )
            Divider()
            permissionRow(
                title: "Accessibility",
                granted: state.accessibilityTrusted,
                detail: "Needed for the global push-to-talk key and to paste into other apps.",
                openAction: Permissions.openAccessibilitySettings
            )
            Divider()
            HStack {
                Button("Request / re-check") { state.requestPermissions() }
                Button("Refresh status") { state.refreshPermissions() }
            }
            Text("After granting Accessibility you may need to quit and relaunch the app.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func permissionRow(title: String, granted: Bool, detail: String, openAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings", action: openAction)
        }
    }
}
