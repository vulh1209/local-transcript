import Foundation
import SwiftWhisper
import AppKit

@Observable
class TranscriptionService {
    enum TranscriptionState {
        case idle
        case recording
        case transcribing
        case completed(String)
        case error(Error)
    }

    private(set) var state: TranscriptionState = .idle
    private(set) var lastTranscription: String = ""

    private let audioRecorder: AudioRecorder
    private let modelManager: ModelManager
    private var floatingPanel: FloatingIndicatorPanel?

    init(audioRecorder: AudioRecorder, modelManager: ModelManager) {
        self.audioRecorder = audioRecorder
        self.modelManager = modelManager
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isTranscribing: Bool {
        if case .transcribing = state { return true }
        return false
    }

    @MainActor
    func startRecording() async throws {
        guard case .idle = state else { return }

        // Ensure model is loaded (lazy loading)
        if !modelManager.isModelLoaded {
            try await modelManager.loadModel()
        }

        // Play start sound
        AudioFeedback.playStartSound()

        // Show floating indicator
        showFloatingIndicator()

        // Start recording
        try audioRecorder.startRecording()
        state = .recording
    }

    @MainActor
    func stopRecording() async {
        guard case .recording = state else { return }

        // Stop recording and get samples
        let samples = audioRecorder.stopRecording()

        // Hide floating indicator
        hideFloatingIndicator()

        // Play stop sound
        AudioFeedback.playStopSound()

        guard !samples.isEmpty else {
            state = .error(TranscriptionError.noAudioCaptured)
            return
        }

        // Transcribe
        state = .transcribing

        do {
            let text = try await transcribe(samples: samples)
            lastTranscription = text
            state = .completed(text)
        } catch {
            state = .error(error)
        }
    }

    /// Toggle recording (for button press)
    @MainActor
    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            do {
                try await startRecording()
            } catch {
                state = .error(error)
            }
        }
    }

    /// Reset to idle state (after showing result)
    func reset() {
        state = .idle
    }

    // MARK: - Private

    private func transcribe(samples: [Float]) async throws -> String {
        guard let whisper = modelManager.whisper else {
            throw TranscriptionError.modelNotLoaded
        }

        // Configure for Vietnamese
        whisper.params.language = .vietnamese

        let segments = try await whisper.transcribe(audioFrames: samples)

        // Join segments with proper spacing
        return segments.map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    @MainActor
    private func showFloatingIndicator() {
        if floatingPanel == nil {
            floatingPanel = FloatingIndicatorPanel(content: FloatingIndicator())
        }
        floatingPanel?.orderFront(nil)
    }

    @MainActor
    private func hideFloatingIndicator() {
        floatingPanel?.close()
        floatingPanel = nil
    }

    enum TranscriptionError: LocalizedError {
        case modelNotLoaded
        case noAudioCaptured

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Whisper model not loaded"
            case .noAudioCaptured:
                return "No audio was captured"
            }
        }
    }
}
