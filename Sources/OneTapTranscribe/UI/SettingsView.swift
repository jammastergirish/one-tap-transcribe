import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, speech, cleanup, prompts, permissions
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general:     return "General"
        case .speech:      return "Speech"
        case .cleanup:     return "Cleanup"
        case .prompts:     return "Prompts"
        case .permissions: return "Permissions"
        }
    }
}

struct SettingsView: View {
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.divider)
            ScrollView {
                Group {
                    switch tab {
                    case .general:     GeneralTab()
                    case .speech:      SpeechTab()
                    case .cleanup:     CleanupTab()
                    case .prompts:     PromptsTab()
                    case .permissions: PermissionsTab()
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.windowBG)
    }

    private var header: some View {
        VStack(spacing: 10) {
            MonoLabel(text: "Settings", size: 12, tracking: 1.6, color: Theme.textSecondary)
                .padding(.top, 14)
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { t in
                    Button { tab = t } label: {
                        Text(t.title.uppercased())
                            .font(.mono(11, weight: tab == t ? .semibold : .regular))
                            .tracking(0.5)
                            .foregroundStyle(tab == t ? Theme.emberText : Theme.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(tab == t ? Theme.emberTint : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared form pieces

private struct FormRow<Content: View>: View {
    let label: String
    var labelWidth: CGFloat = 150
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: labelWidth, alignment: .trailing)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func fieldDescription(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.textTertiary)
        .lineSpacing(1)
        .fixedSize(horizontal: false, vertical: true)
}

private var hairline: some View {
    Divider().overlay(Theme.divider).padding(.vertical, 6)
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormRow(label: "Appearance") {
                Picker("", selection: $store.settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }

            FormRow(label: "Push-to-talk key") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $store.settings.triggerKey) {
                        ForEach(TriggerKey.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().tint(Theme.ember).frame(width: 240)
                    if store.settings.triggerKey == .fn {
                        fieldDescription("Set System Settings → Keyboard → “Press 🌐 key to” → Do Nothing, or Fn also triggers macOS dictation.")
                    }
                }
            }

            hairline

            FormRow(label: "") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Insert text by pasting (⌘V)", isOn: $store.settings.pasteInsteadOfType)
                        .toggleStyle(EmberCheckboxStyle())
                    fieldDescription(store.settings.pasteInsteadOfType
                        ? "Fast and reliable. Briefly uses the clipboard, then restores it."
                        : "Types each character. No clipboard use, but slower.")
                }
            }
            FormRow(label: "") {
                Toggle("Play start/stop sounds", isOn: $store.settings.playFeedbackSounds)
                    .toggleStyle(EmberCheckboxStyle())
            }

            hairline

            FormRow(label: "") {
                Toggle("Show recording overlay", isOn: $store.settings.showOverlay)
                    .toggleStyle(EmberCheckboxStyle())
            }
            FormRow(label: "") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle("Show live text while speaking", isOn: $store.settings.showLiveText)
                            .toggleStyle(EmberCheckboxStyle())
                            .disabled(!store.settings.showOverlay)
                        Spacer()
                        Button("Preview") { state.previewOverlay() }
                            .buttonStyle(GraphiteButtonStyle())
                    }
                    fieldDescription("A floating waveform at the bottom-center while dictating, then “Transcribing…”. Live text shows the confirmed transcript with the settling tail dimmed.")
                }
            }

            hairline

            FormRow(label: "") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Menu-bar only (hide Dock icon)", isOn: $store.settings.menuBarOnly)
                        .toggleStyle(EmberCheckboxStyle())
                    fieldDescription("Off shows a Dock icon and main window — easier to find. Turn on once you’re comfortable using just the menu-bar icon.")
                }
            }
        }
    }
}

// MARK: - Speech-to-Text

private struct SpeechTab: View {
    @EnvironmentObject var store: SettingsStore
    private let lw: CGFloat = 190

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormRow(label: "Engine", labelWidth: lw) {
                Picker("", selection: $store.settings.sttEngine) {
                    ForEach(STTEngineKind.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden().tint(Theme.ember).frame(maxWidth: 320)
            }

            switch store.settings.sttEngine {
            case .whisperKit:
                FormRow(label: "Model", labelWidth: lw) {
                    Picker("", selection: $store.settings.whisperModel) {
                        ForEach(WhisperModel.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().tint(Theme.ember).frame(maxWidth: 320)
                }
                FormRow(label: "Language", labelWidth: lw) {
                    MonoTextField(placeholder: "en, es, or auto", text: $store.settings.whisperLanguage)
                        .frame(width: 220)
                }
                FormRow(label: "", labelWidth: lw) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Stream while speaking", isOn: $store.settings.streaming)
                            .toggleStyle(EmberCheckboxStyle())
                        fieldDescription("Models download from Hugging Face on first use and are cached on disk. Streaming transcribes as you talk and shows live text in the overlay.")
                    }
                }

            case .appleSpeech:
                FormRow(label: "Locale", labelWidth: lw) {
                    MonoTextField(placeholder: "en-US", text: $store.settings.appleSpeechLocale)
                        .frame(width: 220)
                }
                FormRow(label: "", labelWidth: lw) {
                    fieldDescription("Uses Apple’s built-in on-device model. The locale asset downloads once, then runs fully offline.")
                }
            }
        }
    }
}

// MARK: - Cleanup

private struct CleanupTab: View {
    @EnvironmentObject var store: SettingsStore

    @State private var detected: [String] = []
    @State private var availability: String = ""
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormRow(label: "Cleanup engine") {
                Picker("", selection: $store.settings.cleanup) {
                    ForEach(CleanupKind.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden().tint(Theme.ember).frame(maxWidth: 320)
            }

            switch store.settings.cleanup {
            case .none:
                FormRow(label: "") { fieldDescription("Text is inserted exactly as transcribed.") }

            case .appleFoundation:
                FormRow(label: "") { fieldDescription("Runs on Apple’s on-device model. Requires Apple Intelligence to be enabled.") }

            case .ollama:
                FormRow(label: "Endpoint") {
                    MonoTextField(placeholder: "http://localhost:11434", text: $store.settings.ollamaEndpoint)
                        .frame(maxWidth: 320)
                }
                modelRow(binding: $store.settings.ollamaModel, hint: "e.g. llama3.2, qwen2.5")

            case .openAICompatible:
                FormRow(label: "Endpoint") {
                    MonoTextField(placeholder: "http://localhost:8080", text: $store.settings.openAIEndpoint)
                        .frame(maxWidth: 320)
                }
                FormRow(label: "API key") {
                    MonoTextField(placeholder: "blank for local servers", text: $store.settings.openAIAPIKey, isSecure: true)
                        .frame(maxWidth: 320)
                }
                modelRow(binding: $store.settings.openAIModel, hint: "model id")
                FormRow(label: "") {
                    fieldDescription("For MLX: run `mlx_lm.server --port 8080`. Also works with LM Studio, llama.cpp, vLLM.")
                }
            }
        }
        .task(id: cleanupSignature) { await check() }
    }

    @ViewBuilder
    private func modelRow(binding: Binding<String>, hint: String) -> some View {
        FormRow(label: "Model") {
            HStack(spacing: 8) {
                MonoTextField(placeholder: hint, text: binding).frame(maxWidth: 220)
                if !detected.isEmpty {
                    Menu("Detected") {
                        ForEach(detected, id: \.self) { m in
                            Button(m) { binding.wrappedValue = m }
                        }
                    }
                    .frame(width: 100).tint(Theme.ember)
                }
                Button {
                    Task { await check() }
                } label: {
                    if isChecking { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
            }
        }
        FormRow(label: hint) {
            if !availability.isEmpty {
                Label(availability, systemImage: availability.hasPrefix("Ready") ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(availability.hasPrefix("Ready") ? Theme.successText : Theme.emberText)
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
            availability = format(await FoundationModelsEngine().availability()); detected = []
        case .ollama:
            detected = await SystemDetector.ollamaModels(endpoint: s.ollamaEndpoint) ?? []
            availability = format(await OllamaCleanup(endpoint: s.ollamaEndpoint, model: s.ollamaModel).availability())
        case .openAICompatible:
            detected = await SystemDetector.openAIModels(endpoint: s.openAIEndpoint, apiKey: s.openAIAPIKey) ?? []
            availability = format(await OpenAICompatibleCleanup(endpoint: s.openAIEndpoint, model: s.openAIModel, apiKey: s.openAIAPIKey).availability())
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
        VStack(alignment: .leading, spacing: 14) {
            promptSection(title: "Cleanup system prompt",
                          text: $store.settings.cleanupSystemPrompt,
                          reset: DefaultPrompts.cleanupSystem,
                          minHeight: 175)
            promptSection(title: "User message template",
                          text: $store.settings.cleanupUserTemplate,
                          reset: DefaultPrompts.cleanupUserTemplate,
                          minHeight: 66)
            (Text("{{text}}").font(.mono(11.5)).foregroundColor(Theme.emberText)
             + Text(" is replaced with the raw transcript. These prompts are sent to whichever cleanup engine is selected.")
                .font(.system(size: 11.5)).foregroundColor(Theme.textTertiary))
        }
    }

    @ViewBuilder
    private func promptSection(title: String, text: Binding<String>, reset: String, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Reset") { text.wrappedValue = reset }.buttonStyle(GraphiteButtonStyle())
            }
            TextEditor(text: text)
                .font(.mono(12))
                .lineSpacing(2)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: minHeight)
                .background(Theme.fieldBG, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.fieldBorder, lineWidth: 1))
        }
    }
}

// MARK: - Permissions

private struct PermissionsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            permissionRow(title: "Microphone",
                          granted: state.micAuthorized,
                          detail: "Needed to record your voice.",
                          open: Permissions.openMicrophoneSettings)
            hairline
            permissionRow(title: "Accessibility",
                          granted: state.accessibilityTrusted,
                          detail: "Needed for the global push-to-talk key and to paste into other apps.",
                          open: Permissions.openAccessibilitySettings)
            hairline
            HStack {
                Button("Request / re-check") { state.requestPermissions() }
                Button("Refresh status") { state.refreshPermissions() }
            }
            .buttonStyle(GraphiteButtonStyle())
            .padding(.top, 2)
            fieldDescription("After granting Accessibility you may need to quit and relaunch the app.")
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, granted: Bool, detail: String, open: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(granted ? Theme.successText : Theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                fieldDescription(detail)
            }
            Spacer()
            Button("Open Settings", action: open).buttonStyle(GraphiteButtonStyle())
        }
    }
}
