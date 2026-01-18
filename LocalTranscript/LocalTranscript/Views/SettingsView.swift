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
        .frame(width: 500, height: 550)
        .onAppear {
            refreshPermissions()
        }
    }

    private var generalTab: some View {
        Form {
            Section("General") {
                @Bindable var launchManager = appState.launchManager
                Toggle("Start at Login", isOn: $launchManager.launchAtLogin)
                    .onAppear {
                        appState.launchManager.syncFromSystem()
                    }
            }

            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Recording Shortcut:", name: .toggleRecording)

                @Bindable var hotkeyService = appState.hotkeyService
                Picker("Mode", selection: $hotkeyService.mode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(hotkeyDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Auto-segment section only visible when Toggle Mode is enabled (UAT Test 8)
            if appState.hotkeyService.mode == .toggle {
                Section("Auto-Segment") {
                    // Toggle switch instead of picker (UAT Test 9 - no redundant Manual option)
                    Toggle("Enable Auto-Segment", isOn: Binding(
                        get: { segmentMode == SegmentMode.auto.rawValue },
                        set: { segmentMode = $0 ? SegmentMode.auto.rawValue : SegmentMode.manual.rawValue }
                    ))

                    if segmentMode == SegmentMode.auto.rawValue {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Silence Threshold")
                                Spacer()
                                Text(String(format: "%.1fs", silenceThreshold))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $silenceThreshold, in: 1.0...5.0, step: 0.5)
                        }

                        Text("Time of silence before auto-inserting text. Shorter = faster insertion, longer = fewer interruptions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(segmentModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Language") {
                Picker("Language Mode", selection: $languageMode) {
                    ForEach(LanguageMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                KeyboardShortcuts.Recorder("Cycle Language:", name: .cycleLanguage)

                Text("Auto-detect or force specific language. Cycle with hotkey.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Translation") {
                Toggle("Translate to English", isOn: $translateMode)

                Text("When enabled, Vietnamese speech will be translated to English text. Works offline using Whisper's built-in translation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
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
                .disabled(appState.modelManager.isLoading || appState.modelManager.isDownloading)

                // Status row showing current state
                HStack {
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

                // Download progress bar
                if appState.modelManager.isDownloading {
                    ProgressView(value: appState.modelManager.downloadProgress)
                    Text("Downloading: \(Int(appState.modelManager.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Model description
                if let modelInfo = appState.modelManager.currentModelInfo {
                    Text(modelInfo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = appState.modelManager.loadError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Permissions") {
                PermissionRow(
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

                PermissionRow(
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
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var historyTab: some View {
        if let container = appState.historyManager.container {
            HistoryView()
                .modelContainer(container)
        } else {
            ContentUnavailableView(
                "History Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Failed to load history database")
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

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
