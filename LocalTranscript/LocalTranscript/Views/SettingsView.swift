import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var micStatus: PermissionManager.MicrophoneStatus = .notDetermined
    @State private var accessibilityGranted = false

    var body: some View {
        Form {
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
        .frame(width: 450, height: 300)
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
