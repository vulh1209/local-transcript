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

    // Use UserDefaults directly to avoid @AppStorage conflict with @Observable macro
    @ObservationIgnored
    private var languageMode: String {
        get { UserDefaults.standard.string(forKey: "languageMode") ?? LanguageMode.auto.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "languageMode") }
    }

    @ObservationIgnored
    private var translateMode: Bool {
        get { UserDefaults.standard.bool(forKey: "translateMode") }
        set { UserDefaults.standard.set(newValue, forKey: "translateMode") }
    }

    var isTranslateEnabled: Bool { translateMode }

    private let audioRecorder: AudioRecorder
    private let modelManager: ModelManager
    private let historyManager: HistoryManager?
    private let textInsertionService = TextInsertionService()
    @ObservationIgnored private var statusPanel: StatusIndicatorPanel?
    @ObservationIgnored private var recordingStartTime: Date?

    init(audioRecorder: AudioRecorder, modelManager: ModelManager, historyManager: HistoryManager? = nil) {
        self.audioRecorder = audioRecorder
        self.modelManager = modelManager
        self.historyManager = historyManager
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
            // Show downloading indicator with progress updates
            showStatusPanel(.downloading(progress: 0))

            // Set up progress callback to update status panel
            modelManager.onDownloadProgress = { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.showStatusPanel(.downloading(progress: progress))
                }
            }

            try await modelManager.loadModel()

            // Clear progress callback after loading
            modelManager.onDownloadProgress = nil
            print("[StartRecording] Model loaded")
        }

        // Play start sound
        AudioFeedback.playStartSound()

        // Show status panel
        showStatusPanel(.recording)

        // Track recording start time for duration calculation
        recordingStartTime = Date()

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

        // Show transcribing state
        showStatusPanel(.transcribing)

        // Play stop sound
        AudioFeedback.playStopSound()

        guard !samples.isEmpty else {
            logger.error("No audio captured")
            showStatusPanel(.error(message: "No audio captured"))
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

            // Save to history
            if let historyManager = historyManager, let startTime = recordingStartTime {
                let duration = Date().timeIntervalSince(startTime)
                let mode = LanguageMode(rawValue: languageMode) ?? .auto
                historyManager.save(
                    text: text,
                    languageMode: mode.rawValue,
                    duration: duration,
                    wasTranslated: isTranslateEnabled
                )
                logger.info("Saved to history (duration: \(duration)s, translated: \(self.isTranslateEnabled))")
            }

            // Hide status panel on success
            hideStatusPanel()

            // Auto-insert text at cursor
            do {
                try await textInsertionService.insertText(text)
                logger.info("Text inserted at cursor")
            } catch {
                logger.error("Text insertion failed: \(error)")
                // Text is still on clipboard, user can paste manually
            }
        } catch {
            logger.error("Transcription error: \(error)")
            showStatusPanel(.error(message: error.localizedDescription))
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

    /// Show language change feedback (for Plan 01's hotkey to call)
    @MainActor
    func showLanguageChanged(_ mode: String) {
        showStatusPanel(.languageChanged(mode))
    }

    // MARK: - Private

    private func transcribe(samples: [Float]) async throws -> String {
        guard let whisperKit = modelManager.whisperKit else {
            logger.error("Model not loaded")
            throw TranscriptionError.modelNotLoaded
        }

        print("[Transcribe] Starting with \(samples.count) samples")

        // Parse language mode from stored setting
        let mode = LanguageMode(rawValue: languageMode) ?? .auto
        let whisperLanguage = mode.whisperLanguageCode
        print("[Transcribe] Language mode: \(mode.rawValue), whisper language: \(whisperLanguage ?? "auto-detect")")

        // Select task based on translate mode
        let task: DecodingTask = translateMode ? .translate : .transcribe
        print("[Transcribe] Translate mode: \(translateMode), task: \(task)")

        let options = DecodingOptions(
            task: task,
            language: whisperLanguage,
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
    private func showStatusPanel(_ state: StatusIndicatorState) {
        if statusPanel == nil {
            statusPanel = StatusIndicatorPanel()
        }
        statusPanel?.updateState(state)
        statusPanel?.orderFront(nil)
    }

    @MainActor
    private func hideStatusPanel() {
        statusPanel?.close()
        statusPanel = nil
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
