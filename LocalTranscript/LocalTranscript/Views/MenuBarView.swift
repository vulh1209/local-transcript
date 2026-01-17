import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            // Model status
            if appState.modelManager.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.modelManager.loadProgress.isEmpty ? "Loading model..." : appState.modelManager.loadProgress)
                }
            } else if appState.modelManager.isModelLoaded {
                Label("Ready", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else if appState.modelManager.isModelFilePresent {
                Label("Model ready to load", systemImage: "circle")
                    .foregroundStyle(.secondary)
            } else {
                Label("Model not found", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            Divider()

            // Load model button (for testing - will be automatic in Phase 2)
            if !appState.modelManager.isModelLoaded && appState.modelManager.isModelFilePresent && !appState.modelManager.isLoading {
                Button("Load Model") {
                    Task {
                        try? await appState.modelManager.loadModel()
                    }
                }
            }

            if appState.modelManager.isModelLoaded {
                Button("Unload Model") {
                    appState.modelManager.unloadModel()
                }
            }

            Divider()

            Button("Settings...") {
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit LocalTranscript") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
