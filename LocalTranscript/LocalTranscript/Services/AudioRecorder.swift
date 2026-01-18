import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.voicetype.localtranscript", category: "AudioRecorder")

@Observable
class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioConverter: AVAudioConverter?
    private var accumulatedSamples: [Float] = []

    private(set) var isRecording = false

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    // MARK: - VAD Integration

    /// State machine for tracking speech/silence during auto-segment mode
    private enum VADState {
        case idle           // Not speaking (waiting for speech)
        case speech         // Voice detected (recording speech)
        case silencePending // Silence started, waiting for threshold
    }

    /// VAD service for voice activity detection (injected from AppState)
    var vadService: VADService?

    /// Circular buffer for continuous recording in auto-segment mode
    private var circularBuffer: CircularAudioBuffer?

    /// Current VAD state during auto-segment mode
    private var vadState: VADState = .idle

    /// Timestamp when silence started (for threshold checking)
    private var silenceStartTime: Date?

    /// Running count of samples processed since last speech start (for segment tracking)
    private var samplesInCurrentSegment: Int = 0

    /// Sample index when current speech segment started (for extraction)
    private var speechStartSampleIndex: Int = 0

    /// Silence threshold in seconds (user configurable, default 2.0s per SEG-01)
    var silenceThreshold: TimeInterval = 2.0

    /// Callback when silence exceeds threshold and segment is ready for transcription
    var onSilenceDetected: (([Float]) -> Void)?

    /// Whether auto-segment mode is enabled (continuous dictation with VAD)
    var isAutoSegmentEnabled: Bool = false

    /// Buffer for accumulating samples until we have enough for a VAD chunk
    private var vadChunkBuffer: [Float] = []

    /// Required chunk size for VAD processing (4096 samples = 256ms at 16kHz)
    private static let vadChunkSize = 4096

    enum AudioError: LocalizedError {
        case converterCreationFailed

        var errorDescription: String? {
            switch self {
            case .converterCreationFailed:
                return "Failed to create audio format converter"
            }
        }
    }

    /// Initialize VAD service for pre-warming before recording starts
    /// Call this when user enables auto-segment mode
    func initializeVAD() async throws {
        guard let vad = vadService else { return }
        if await !vad.isInitialized {
            try await vad.initialize()
            logger.info("VAD initialized for auto-segment mode")
        }
    }

    /// Start recording from microphone, converting audio to 16kHz mono Float32.
    /// Requires microphone permission to be granted.
    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Query native format at runtime - do NOT hardcode sample rate
        // AirPods may be 16kHz, built-in mic 44.1kHz, USB mics 48kHz
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Create converter from native input format to 16kHz mono Float32 (Whisper requirement)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterCreationFailed
        }

        audioConverter = converter
        accumulatedSamples = []

        // Initialize auto-segment infrastructure if enabled
        if isAutoSegmentEnabled {
            circularBuffer = CircularAudioBuffer()
            vadState = .idle
            silenceStartTime = nil
            samplesInCurrentSegment = 0
            speechStartSampleIndex = 0
            vadChunkBuffer = []

            // Reset VAD state for new recording session
            if let vad = vadService {
                Task {
                    await vad.reset()
                    await vad.setSilenceDuration(silenceThreshold)
                }
            }
            logger.info("Auto-segment mode: initialized circular buffer and VAD")
        }

        // Install tap on input node - callback runs on audio thread
        // Keep processing minimal: only convert and append
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        isRecording = true
    }

    /// Stop recording and return accumulated audio samples.
    /// Returns [Float] samples at 16kHz mono, ready for Whisper transcription.
    func stopRecording() -> [Float] {
        guard isRecording, let engine = audioEngine else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        isRecording = false
        audioEngine = nil
        audioConverter = nil

        // Handle based on mode
        if isAutoSegmentEnabled, let buffer = circularBuffer {
            // Extract any remaining audio from circular buffer
            let samples = buffer.extract()
            circularBuffer = nil
            vadState = .idle
            vadChunkBuffer = []
            logger.info("Auto-segment mode: extracted \(samples.count) remaining samples")
            return samples
        } else {
            // Return samples and clear accumulator (manual mode)
            let samples = accumulatedSamples
            accumulatedSamples = []
            return samples
        }
    }

    /// Convert incoming buffer to 16kHz mono and append to accumulated samples.
    /// This runs on the audio thread - keep it fast.
    private func processBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }

        // Calculate output frame count based on input duration and target sample rate
        let duration = Double(inputBuffer.frameLength) / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(16000.0 * duration)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        var inputBufferConsumed = false

        // AVAudioConverter.convert uses a callback pattern for input data
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputBufferConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputBufferConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        // Extract Float samples from converted buffer
        guard let channelData = outputBuffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(
            start: channelData,
            count: Int(outputBuffer.frameLength)
        ))

        // Route to appropriate handler based on mode
        if isAutoSegmentEnabled {
            processAutoSegment(samples)
        } else {
            accumulatedSamples.append(contentsOf: samples)
        }
    }

    /// Process samples in auto-segment mode with VAD
    private func processAutoSegment(_ samples: [Float]) {
        guard let buffer = circularBuffer else { return }

        // Always store in circular buffer
        buffer.write(samples)

        // Accumulate samples for VAD chunk processing
        vadChunkBuffer.append(contentsOf: samples)

        // Process complete 4096-sample chunks through VAD
        while vadChunkBuffer.count >= Self.vadChunkSize {
            let chunk = Array(vadChunkBuffer.prefix(Self.vadChunkSize))
            vadChunkBuffer.removeFirst(Self.vadChunkSize)

            // Process VAD asynchronously to not block audio thread
            processVADChunk(chunk)
        }
    }

    /// Process a single VAD chunk (called from audio thread, dispatches async work)
    private func processVADChunk(_ chunk: [Float]) {
        guard let vad = vadService else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            do {
                let result = try await vad.processChunk(chunk)
                await self.handleVADResult(result, chunkSize: chunk.count)
            } catch {
                logger.error("VAD processing error: \(error.localizedDescription)")
            }
        }
    }

    /// Handle VAD result and update state machine
    @MainActor
    private func handleVADResult(_ result: VADResult, chunkSize: Int) {
        // Track samples for segment extraction
        samplesInCurrentSegment += chunkSize

        switch vadState {
        case .idle:
            if result.isVoiceActive {
                // Speech started
                vadState = .speech
                speechStartSampleIndex = max(0, (circularBuffer?.availableCount ?? 0) - samplesInCurrentSegment)
                samplesInCurrentSegment = chunkSize
                logger.debug("VAD: speech started")
            }

        case .speech:
            if !result.isVoiceActive {
                // Silence detected, start threshold timer
                vadState = .silencePending
                silenceStartTime = Date()
                logger.debug("VAD: silence started, waiting for threshold")
            }

        case .silencePending:
            if result.isVoiceActive {
                // Speech resumed, cancel pending
                vadState = .speech
                silenceStartTime = nil
                logger.debug("VAD: speech resumed, canceled silence")
            } else if let startTime = silenceStartTime {
                // Check if silence threshold exceeded
                let silenceDuration = Date().timeIntervalSince(startTime)
                if silenceDuration >= silenceThreshold {
                    // Segment complete - extract and callback
                    extractAndDeliverSegment()
                    vadState = .idle
                    silenceStartTime = nil
                    samplesInCurrentSegment = 0
                    logger.info("VAD: silence threshold reached, segment delivered")
                }
            }
        }
    }

    /// Extract audio segment from buffer and deliver via callback
    @MainActor
    private func extractAndDeliverSegment() {
        guard let buffer = circularBuffer else { return }

        // Extract samples, keeping some overlap for context
        // Keep last 0.5 seconds (8000 samples) for smooth transitions
        let overlapSamples = 8000
        let samples = buffer.extractAndKeep(keepLast: overlapSamples)

        guard !samples.isEmpty else {
            logger.warning("VAD: attempted to extract empty segment")
            return
        }

        logger.info("VAD: extracted segment with \(samples.count) samples (\(Double(samples.count) / 16000.0)s)")

        // Deliver to callback
        onSilenceDetected?(samples)
    }
}
