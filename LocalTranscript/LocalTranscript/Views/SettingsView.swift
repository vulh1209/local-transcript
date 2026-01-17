import SwiftUI

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

            Section("Model") {
                HStack {
                    Text("PhoWhisper Medium")
                    Spacer()
                    if appState.modelManager.isModelLoaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Loaded")
                            .foregroundStyle(.secondary)
                    } else if appState.modelManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    } else if appState.modelManager.isModelFilePresent {
                        Text("Ready to load")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Model not found")
                            .foregroundStyle(.secondary)
                    }
                }

                if !appState.modelManager.isModelFilePresent {
                    Text("Download model from HuggingFace and place in:\n\(appState.modelManager.modelStoragePath.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Open Model Folder") {
                        NSWorkspace.shared.open(appState.modelManager.modelStoragePath)
                    }
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
                    description: "Required for text insertion (Phase 3)",
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
        .frame(width: 450, height: 400)
        .onAppear {
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        micStatus = appState.permissionManager.checkMicrophonePermission()
        accessibilityGranted = appState.permissionManager.checkAccessibilityPermission()
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
