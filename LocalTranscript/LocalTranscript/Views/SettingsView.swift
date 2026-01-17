import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var micStatus: PermissionManager.MicrophoneStatus = .notDetermined
    @State private var accessibilityGranted = false

    var body: some View {
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

            Section("Model") {
                HStack {
                    Text("Whisper Small")
                    Spacer()
                    if appState.modelManager.isModelLoaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Loaded")
                            .foregroundStyle(.secondary)
                    } else if appState.modelManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                        Text(appState.modelManager.loadProgress)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.blue)
                        Text("Downloads on first use")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Model downloads automatically via WhisperKit (~250MB)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
        .frame(width: 450, height: 480)
        .onAppear {
            refreshPermissions()
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
