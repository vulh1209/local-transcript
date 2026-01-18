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
        case continuousRecording  // Auto-segment mode: recording with VAD active
        case transcribing
        case completed(String)
        case error(Error)
    }

    private(set) var state: TranscriptionState = .idle
    private(set) var lastTranscription: String = ""

    /// Number of segments pending transcription (for UI display per SEG-07)
    private(set) var pendingSegments: Int = 0

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

    @ObservationIgnored
    private var segmentMode: String {
        get { UserDefaults.standard.string(forKey: "segmentMode") ?? SegmentMode.manual.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "segmentMode") }
    }

    @ObservationIgnored
    private var silenceThreshold: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "silenceThreshold")
            return value > 0 ? value : 2.0  // Default 2.0s per SEG-01
        }
        set { UserDefaults.standard.set(newValue, forKey: "silenceThreshold") }
    }

    var isTranslateEnabled: Bool { translateMode }

    /// Whether auto-segment mode is enabled
    var isContinuousMode: Bool { segmentMode == SegmentMode.auto.rawValue }

    private let audioRecorder: AudioRecorder
    private let modelManager: ModelManager
    private let historyManager: HistoryManager?
    private let textInsertionService = TextInsertionService()
    private let transcriptionQueue = TranscriptionQueue()
    @ObservationIgnored private var statusPanel: StatusIndicatorPanel?
    @ObservationIgnored private var recordingStartTime: Date?
    @ObservationIgnored private var segmentStartTime: Date?

    /// RMS energy threshold for detecting silent audio (prevents Whisper hallucination)
    private let rmsThreshold: Float = 0.01

    init(audioRecorder: AudioRecorder, modelManager: ModelManager, historyManager: HistoryManager? = nil) {
        self.audioRecorder = audioRecorder
        self.modelManager = modelManager
        self.historyManager = historyManager
    }

    var isRecording: Bool {
        switch state {
        case .recording, .continuousRecording:
            return true
        default:
            return false
        }
    }

    var isTranscribing: Bool {
        if case .transcribing = state { return true }
        return false
    }

    @MainActor
    func startRecording() async throws {
        print("[StartRecording] Called, state = \(state), isContinuousMode = \(isContinuousMode)")

        // Route to appropriate mode
        if isContinuousMode {
            try await startContinuousRecording()
        } else {
            try await startManualRecording()
        }
    }

    /// Start recording in manual mode (existing behavior)
    @MainActor
    private func startManualRecording() async throws {
        print("[StartManualRecording] Called, state = \(state)")

        // Auto-reset from terminal states (completed/error) so user can record again
        switch state {
        case .completed, .error:
            print("[StartManualRecording] Auto-resetting from terminal state")
            state = .idle
        case .recording, .continuousRecording, .transcribing:
            print("[StartManualRecording] Already recording/transcribing, returning")
            return
        case .idle:
            break
        }

        // Ensure model is loaded (lazy loading)
        try await ensureModelLoaded()

        // Play start sound
        AudioFeedback.playStartSound()

        // Show status panel
        showStatusPanel(.recording)

        // Track recording start time for duration calculation
        recordingStartTime = Date()

        // Ensure auto-segment is disabled for manual mode
        audioRecorder.isAutoSegmentEnabled = false

        // Start recording
        print("[StartManualRecording] Starting audio recorder...")
        try audioRecorder.startRecording()
        state = .recording
        print("[StartManualRecording] Now recording")
    }

    /// Start recording in continuous/auto-segment mode
    @MainActor
    private func startContinuousRecording() async throws {
        print("[StartContinuousRecording] Called, state = \(state)")

        // Auto-reset from terminal states
        switch state {
        case .completed, .error:
            print("[StartContinuousRecording] Auto-resetting from terminal state")
            state = .idle
        case .recording, .continuousRecording, .transcribing:
            print("[StartContinuousRecording] Already recording/transcribing, returning")
            return
        case .idle:
            break
        }

        // Ensure model is loaded
        try await ensureModelLoaded()

        // Initialize VAD if needed (show downloading state)
        try await initializeVADIfNeeded()

        // Play start sound
        AudioFeedback.playStartSound()

        // Show continuous recording status
        showStatusPanel(.recording)

        // Track recording start time
        recordingStartTime = Date()
        segmentStartTime = Date()

        // Configure audio recorder for auto-segment mode
        audioRecorder.isAutoSegmentEnabled = true
        audioRecorder.silenceThreshold = silenceThreshold
        audioRecorder.onSilenceDetected = { [weak self] samples in
            self?.handleSegment(samples)
        }

        // Start recording
        print("[StartContinuousRecording] Starting audio recorder with VAD...")
        try audioRecorder.startRecording()
        state = .continuousRecording
        print("[StartContinuousRecording] Now continuous recording with VAD")
    }

    @MainActor
    func stopRecording() async {
        print("[StopRecording] Called, state = \(state)")

        switch state {
        case .recording:
            await stopManualRecording()
        case .continuousRecording:
            await stopContinuousRecording()
        default:
            print("[StopRecording] Not recording, returning")
            return
        }
    }

    /// Stop recording in manual mode
    @MainActor
    private func stopManualRecording() async {
        print("[StopManualRecording] Called")

        // Stop recording and get samples
        let samples = audioRecorder.stopRecording()
        print("[StopManualRecording] Got \(samples.count) samples (\(Double(samples.count) / 16000.0) seconds)")

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
            saveToHistory(text: text, startTime: recordingStartTime)

            // Hide status panel on success
            hideStatusPanel()

            // Auto-insert text at cursor
            await insertTextAtCursor(text)
        } catch {
            logger.error("Transcription error: \(error)")
            showStatusPanel(.error(message: error.localizedDescription))
            state = .error(error)
        }
    }

    /// Stop recording in continuous mode
    @MainActor
    private func stopContinuousRecording() async {
        print("[StopContinuousRecording] Called, pendingSegments = \(pendingSegments)")

        // Play stop sound
        AudioFeedback.playStopSound()

        // Stop recording and get any remaining samples
        let samples = audioRecorder.stopRecording()
        print("[StopContinuousRecording] Got \(samples.count) remaining samples")

        // Reset audio recorder settings
        audioRecorder.isAutoSegmentEnabled = false
        audioRecorder.onSilenceDetected = nil

        // If there are remaining samples, queue final segment
        if !samples.isEmpty {
            handleSegment(samples)
        }

        // If segments are still being processed, show waiting state
        if pendingSegments > 0 {
            showStatusPanel(.transcribing)
            logger.info("Waiting for \(self.pendingSegments) pending segments to complete")
            // Note: We don't block here - segments complete in background
        } else {
            hideStatusPanel()
        }

        state = .idle
        print("[StopContinuousRecording] Stopped, returning to idle")
    }

    /// Handle a segment detected by VAD (called from AudioRecorder callback)
    private func handleSegment(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        // Pre-transcription RMS energy check to reject silent audio (prevents Whisper hallucination)
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        guard rms > rmsThreshold else {
            logger.info("Segment rejected: RMS energy \(rms) below threshold \(self.rmsThreshold)")
            return
        }

        let sampleCount = samples.count
        let duration = Double(sampleCount) / 16000.0
        logger.info("Handling segment: \(sampleCount) samples (\(duration)s), RMS: \(rms)")

        // Increment pending count on main thread
        Task { @MainActor in
            self.pendingSegments += 1
            // Brief visual feedback that segment was detected (SEG-03)
            self.showStatusPanel(.transcribing)
        }

        // Queue for transcription
        Task {
            do {
                let text = try await transcriptionQueue.enqueue { [weak self] in
                    guard let self = self else { throw TranscriptionError.modelNotLoaded }
                    return try await self.transcribe(samples: samples)
                }

                // Process result on main thread
                let shouldInsertText = await MainActor.run { [weak self] () -> Bool in
                    guard let self = self else { return false }

                    self.pendingSegments = max(0, self.pendingSegments - 1)

                    if !text.isEmpty {
                        self.lastTranscription = text
                        logger.info("Segment transcribed: '\(text)'")

                        // Save to history
                        self.saveToHistory(text: text, startTime: self.segmentStartTime)
                        self.segmentStartTime = Date()
                    }

                    // Hide status if no more pending and not recording
                    if self.pendingSegments == 0 {
                        if case .continuousRecording = self.state {
                            // Return to continuous recording state (from .transcribing)
                            self.showStatusPanel(.continuousRecording(pendingSegments: 0))
                        } else {
                            self.hideStatusPanel()
                        }
                    }

                    return !text.isEmpty
                }

                // Insert text after main actor work completes (awaited, not fire-and-forget)
                if shouldInsertText {
                    await self.insertTextAtCursor(text)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.pendingSegments = max(0, (self?.pendingSegments ?? 1) - 1)
                    logger.error("Segment transcription failed: \(error.localizedDescription)")
                }
            }
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

    // MARK: - Private Helpers

    @MainActor
    private func ensureModelLoaded() async throws {
        if !modelManager.isModelLoaded {
            print("[EnsureModelLoaded] Loading model...")
            showStatusPanel(.downloading(progress: 0))

            modelManager.onDownloadProgress = { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.showStatusPanel(.downloading(progress: progress))
                }
            }

            try await modelManager.loadModel()
            modelManager.onDownloadProgress = nil
            print("[EnsureModelLoaded] Model loaded")
        }
    }

    @MainActor
    private func initializeVADIfNeeded() async throws {
        // Initialize VAD model if not already done
        try await audioRecorder.initializeVAD()
        logger.info("VAD initialized for continuous recording")
    }

    private func saveToHistory(text: String, startTime: Date?) {
        guard let historyManager = historyManager, let startTime = startTime else { return }

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

    @MainActor
    private func insertTextAtCursor(_ text: String) async {
        do {
            try await textInsertionService.insertText(text)
            logger.info("Text inserted at cursor")
        } catch {
            logger.error("Text insertion failed: \(error)")
            // Text is still on clipboard, user can paste manually
        }
    }

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

            // Filter segments using WhisperKit metrics to reject hallucinations
            let allSegments = results.flatMap { $0.segments }
            let validSegments = allSegments.filter { segment in
                // Reject if high probability of no speech (threshold: 0.7)
                guard segment.noSpeechProb < 0.7 else {
                    logger.info("Segment rejected: noSpeechProb \(segment.noSpeechProb) >= 0.7")
                    return false
                }
                // Reject if very low confidence (threshold: -1.5)
                guard segment.avgLogprob > -1.5 else {
                    logger.info("Segment rejected: avgLogprob \(segment.avgLogprob) <= -1.5")
                    return false
                }
                // Reject if high compression ratio indicating repetitive hallucination (threshold: 2.4)
                guard segment.compressionRatio < 2.4 else {
                    logger.info("Segment rejected: compressionRatio \(segment.compressionRatio) >= 2.4")
                    return false
                }
                return true
            }

            // Build text from valid segments only
            let text = validSegments.map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet.whitespaces)

            print("[Transcribe] Filtered \(allSegments.count) -> \(validSegments.count) segments, text: \(text)")
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
