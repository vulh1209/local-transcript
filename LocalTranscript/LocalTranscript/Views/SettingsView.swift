import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var micStatus: PermissionManager.MicrophoneStatus = .notDetermined
    @State private var accessibilityGranted = false
    @AppStorage("languageMode") private var languageMode = LanguageMode.auto.rawValue
    @AppStorage("translateMode") private var translateMode = false
    @AppStorage("segmentMode") private var segmentMode = SegmentMode.manual.rawValue
    @AppStorage("silenceThreshold") private var silenceThreshold: Double = 2.0
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            historyTab
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)
        }
        .frame(width: 520, height: 620)
        .onAppear {
            refreshPermissions()
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(spacing: GlassDesign.Spacing.md) {
                // General Section
                GlassSection(title: "General", icon: "gearshape.fill") {
                    @Bindable var launchManager = appState.launchManager
                    GlassToggle(
                        "Start at Login",
                        isOn: $launchManager.launchAtLogin
                    )
                    .onAppear {
                        appState.launchManager.syncFromSystem()
                    }
                }

                // Hotkey Section
                GlassSection(title: "Hotkey", icon: "keyboard.fill") {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                        HStack {
                            Text("Recording Shortcut")
                                .font(.system(size: 13))
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .toggleRecording)
                        }

                        @Bindable var hotkeyService = appState.hotkeyService
                        GlassSegmentedPicker(
                            selection: $hotkeyService.mode,
                            options: RecordingMode.allCases
                        ) { mode in
                            Text(mode.rawValue)
                        }

                        Text(hotkeyDescription)
                            .font(.caption)
                            .foregroundStyle(GlassDesign.Colors.textTertiary)
                    }
                }

                // Auto-segment section only visible when Toggle Mode is enabled
                if appState.hotkeyService.mode == .toggle {
                    GlassSection(title: "Auto-Segment", icon: "waveform.badge.mic") {
                        VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                            GlassToggle(
                                "Enable Auto-Segment",
                                isOn: Binding(
                                    get: { segmentMode == SegmentMode.auto.rawValue },
                                    set: { segmentMode = $0 ? SegmentMode.auto.rawValue : SegmentMode.manual.rawValue }
                                )
                            )

                            if segmentMode == SegmentMode.auto.rawValue {
                                GlassSlider(
                                    value: $silenceThreshold,
                                    range: 1.0...5.0,
                                    step: 0.5,
                                    title: "Silence Threshold",
                                    valueLabel: String(format: "%.1fs", silenceThreshold)
                                )

                                Text("Time of silence before auto-inserting text. Shorter = faster, longer = fewer interruptions.")
                                    .font(.caption)
                                    .foregroundStyle(GlassDesign.Colors.textTertiary)
                            }

                            Text(segmentModeDescription)
                                .font(.caption)
                                .foregroundStyle(GlassDesign.Colors.textTertiary)
                        }
                    }
                }

                // Language Section
                GlassSection(title: "Language", icon: "globe") {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                        GlassSegmentedPicker(
                            selection: $languageMode,
                            options: LanguageMode.allCases.map { $0.rawValue }
                        ) { mode in
                            Text(mode)
                        }

                        HStack {
                            Text("Cycle Language")
                                .font(.system(size: 13))
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .cycleLanguage)
                        }

                        Text("Auto-detect or force specific language. Cycle with hotkey.")
                            .font(.caption)
                            .foregroundStyle(GlassDesign.Colors.textTertiary)
                    }
                }

                // Translation Section
                GlassSection(title: "Translation", icon: "character.bubble") {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                        GlassToggle("Translate to English", isOn: $translateMode)

                        Text("Vietnamese speech will be translated to English text. Works offline using Whisper's built-in translation.")
                            .font(.caption)
                            .foregroundStyle(GlassDesign.Colors.textTertiary)
                    }
                }

                // Translation Hotkey Section
                GlassSection(title: "Translation Hotkey", icon: "globe.badge.chevron.backward") {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                        HStack {
                            Text("Translate Selection")
                                .font(.system(size: 13))
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .translateSelection)
                        }

                        Text("Select text and press the hotkey to translate. Works with any selected text in any application.")
                            .font(.caption)
                            .foregroundStyle(GlassDesign.Colors.textTertiary)
                    }
                }

                // Model Section
                GlassSection(title: "Model", icon: "cpu") {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                        // Model picker
                        Picker("Model Size", selection: Binding(
                            get: { appState.modelManager.selectedModel },
                            set: { newValue in
                                Task {
                                    try? await appState.modelManager.switchModel(to: newValue)
                                }
                            }
                        )) {
                            ForEach(ModelManager.availableModels) { model in
                                HStack {
                                    Text(model.name)
                                    Spacer()
                                    Text(model.size)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(appState.modelManager.isLoading || appState.modelManager.isDownloading)

                        // Status row showing current state
                        HStack(spacing: GlassDesign.Spacing.xs) {
                            if appState.modelManager.isModelLoaded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Loaded")
                                    .foregroundStyle(.secondary)
                            } else if appState.modelManager.isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                                Text(appState.modelManager.loadProgress)
                                    .foregroundStyle(.secondary)
                            } else if appState.modelManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.blue)
                                Text("Downloads on first use")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 12))

                        // Download progress bar
                        if appState.modelManager.isDownloading {
                            VStack(alignment: .leading, spacing: GlassDesign.Spacing.xxs) {
                                ProgressView(value: appState.modelManager.downloadProgress)
                                    .tint(.accentColor)
                                Text("Downloading: \(Int(appState.modelManager.downloadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Model description
                        if let modelInfo = appState.modelManager.currentModelInfo {
                            Text(modelInfo.description)
                                .font(.caption)
                                .foregroundStyle(GlassDesign.Colors.textTertiary)
                        }

                        if let error = appState.modelManager.loadError {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Permissions Section
                GlassSection(title: "Permissions", icon: "lock.shield.fill") {
                    VStack(spacing: GlassDesign.Spacing.sm) {
                        GlassPermissionRow(
                            title: "Microphone",
                            description: "Required for voice recording",
                            isGranted: micStatus == .authorized,
                            action: {
                                if micStatus == .notDetermined {
                                    Task {
                                        _ = await appState.permissionManager.requestMicrophonePermission()
                                        refreshPermissions()
                                    }
                                } else {
                                    appState.permissionManager.openMicrophoneSettings()
                                }
                            }
                        )

                        Divider()
                            .background(GlassDesign.Colors.glassBorderSubtle)

                        GlassPermissionRow(
                            title: "Accessibility",
                            description: "Required for text insertion and global hotkey",
                            isGranted: accessibilityGranted,
                            action: {
                                if !accessibilityGranted {
                                    appState.permissionManager.requestAccessibilityPermission()
                                } else {
                                    appState.permissionManager.openAccessibilitySettings()
                                }
                            }
                        )
                    }
                }
            }
            .padding(GlassDesign.Spacing.lg)
        }
    }

    @ViewBuilder
    private var historyTab: some View {
        if let container = appState.historyManager.container {
            HistoryView()
                .modelContainer(container)
        } else {
            GlassEmptyState(
                icon: "exclamationmark.triangle",
                title: "History Unavailable",
                description: "Failed to load history database"
            )
        }
    }

    private func refreshPermissions() {
        micStatus = appState.permissionManager.checkMicrophonePermission()
        accessibilityGranted = appState.permissionManager.checkAccessibilityPermission()
    }

    private var hotkeyDescription: String {
        switch appState.hotkeyService.mode {
        case .holdToTalk:
            return "Hold the shortcut to record, release to transcribe and insert"
        case .toggle:
            return "Press once to start recording, press again to stop and insert"
        }
    }

    private var segmentModeDescription: String {
        if let mode = SegmentMode(rawValue: segmentMode) {
            switch mode {
            case .manual:
                return "Standard mode. Hold hotkey to record, release to transcribe."
            case .auto:
                return "Continuous dictation. Text automatically inserts when you pause speaking."
            }
        }
        return ""
    }
}
