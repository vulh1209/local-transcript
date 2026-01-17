import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            // Recording section
            recordingSection

            Divider()

            // Last transcription result
            if !appState.transcriptionService.lastTranscription.isEmpty {
                transcriptionResultSection
                Divider()
            }

            // Error display
            if case .error(let error) = appState.transcriptionService.state {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                Divider()
            }

            // Model status
            modelStatusSection

            Divider()

            // Model controls (for testing)
            modelControlsSection

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

    // MARK: - Recording Section

    @ViewBuilder
    private var recordingSection: some View {
        Button {
            Task {
                await appState.transcriptionService.toggleRecording()
            }
        } label: {
            if appState.transcriptionService.isRecording {
                Label("Stop Recording", systemImage: "stop.circle.fill")
            } else if appState.transcriptionService.isTranscribing {
                Label("Transcribing...", systemImage: "waveform")
            } else {
                Label("Start Recording", systemImage: "record.circle")
            }
        }
        .disabled(appState.transcriptionService.isTranscribing)
    }

    // MARK: - Transcription Result Section

    @ViewBuilder
    private var transcriptionResultSection: some View {
        Text("Last Transcription")
            .font(.caption)
            .foregroundStyle(.secondary)

        Text(appState.transcriptionService.lastTranscription)
            .lineLimit(3)

        Button("Copy to Clipboard") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                appState.transcriptionService.lastTranscription,
                forType: .string
            )
        }
    }

    // MARK: - Model Status Section

    @ViewBuilder
    private var modelStatusSection: some View {
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
    }

    // MARK: - Model Controls Section

    @ViewBuilder
    private var modelControlsSection: some View {
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
    }
}
