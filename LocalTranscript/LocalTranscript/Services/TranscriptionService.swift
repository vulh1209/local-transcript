import Foundation
import WhisperKit
import AppKit
import os.log

private let logger = Logger(subsystem: "com.voicetype.localtranscript", category: "TranscriptionService")

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
        print("[StartRecording] Called, state = \(state)")

        // Auto-reset from terminal states (completed/error) so user can record again
        switch state {
        case .completed, .error:
            print("[StartRecording] Auto-resetting from terminal state")
            state = .idle
        case .recording, .transcribing:
            print("[StartRecording] Already recording/transcribing, returning")
            return
        case .idle:
            break
        }

        // Ensure model is loaded (lazy loading)
        if !modelManager.isModelLoaded {
            print("[StartRecording] Loading model...")
            try await modelManager.loadModel()
            print("[StartRecording] Model loaded")
        }

        // Play start sound
        AudioFeedback.playStartSound()

        // Show floating indicator
        showFloatingIndicator()

        // Start recording
        print("[StartRecording] Starting audio recorder...")
        try audioRecorder.startRecording()
        state = .recording
        print("[StartRecording] Now recording")
    }

    @MainActor
    func stopRecording() async {
        print("[StopRecording] Called, state = \(state)")
        guard case .recording = state else {
            print("[StopRecording] Not recording, returning")
            return
        }

        // Stop recording and get samples
        let samples = audioRecorder.stopRecording()
        print("[StopRecording] Got \(samples.count) samples (\(Double(samples.count) / 16000.0) seconds)")

        // Hide floating indicator
        hideFloatingIndicator()

        // Play stop sound
        AudioFeedback.playStopSound()

        guard !samples.isEmpty else {
            logger.error("No audio captured")
            state = .error(TranscriptionError.noAudioCaptured)
            return
        }

        // Transcribe
        state = .transcribing
        logger.info("Starting transcription...")

        do {
            let text = try await transcribe(samples: samples)
            logger.info("Transcription result: '\(text)'")
            lastTranscription = text
            state = .completed(text)
        } catch {
            logger.error("Transcription error: \(error)")
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
        guard let whisperKit = modelManager.whisperKit else {
            logger.error("Model not loaded")
            throw TranscriptionError.modelNotLoaded
        }

        print("[Transcribe] Starting with \(samples.count) samples")

        // Configure for Vietnamese language
        let options = DecodingOptions(
            task: .transcribe,
            language: "vi",  // Vietnamese
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        do {
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)

            print("[Transcribe] Got \(results.count) results")

            // Join all transcription results
            let text = results.compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet.whitespaces)

            print("[Transcribe] Text: \(text)")
            return text
        } catch {
            print("[Transcribe] Error: \(error)")
            throw error
        }
    }

    @MainActor
    private func showFloatingIndicator() {
        if floatingPanel == nil {
            floatingPanel = FloatingIndicatorPanel()
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
