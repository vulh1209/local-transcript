import Foundation
import FluidAudio

/// Result of VAD processing on an audio chunk
struct VADResult: Sendable {
    /// Whether voice activity was detected in this chunk
    let isVoiceActive: Bool
    /// Confidence score from 0.0 to 1.0
    let confidence: Float
    /// Speech start event if detected (sample index)
    let speechStartSample: Int?
    /// Speech end event if detected (sample index)
    let speechEndSample: Int?
}

/// Errors that can occur during VAD operations
enum VADError: LocalizedError {
    case notInitialized
    case invalidChunkSize(expected: Int, actual: Int)
    case processingFailed(Error)
    case initializationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "VAD service is not initialized"
        case .invalidChunkSize(let expected, let actual):
            return "Invalid chunk size: expected \(expected) samples, got \(actual)"
        case .processingFailed(let error):
            return "VAD processing failed: \(error.localizedDescription)"
        case .initializationFailed(let error):
            return "Failed to initialize VAD: \(error.localizedDescription)"
        }
    }
}

/// Voice Activity Detection service wrapping FluidAudio's SileroVAD
///
/// Usage:
/// 1. Call initialize() once to download and load the VAD model
/// 2. Feed 4096-sample chunks at 16kHz using processChunk()
/// 3. Call reset() between utterances to clear internal state
///
/// FluidAudio's VadManager uses 4096 samples per chunk (256ms at 16kHz).
/// It provides built-in streaming state machine with speech start/end events.
actor VADService {
    /// Required chunk size for SileroVAD: 4096 samples at 16kHz = 256ms
    static let requiredChunkSize = VadManager.chunkSize  // 4096

    /// Sample rate required by SileroVAD
    static let sampleRate = VadManager.sampleRate  // 16000

    /// Default probability threshold above which speech is detected
    static let defaultThreshold: Float = 0.85

    private var vadManager: VadManager?
    private var streamState: VadStreamState?

    /// Whether the VAD model has been initialized
    private(set) var isInitialized: Bool = false

    /// Configurable silence duration threshold for speech segmentation
    private var silenceDuration: TimeInterval

    init(silenceDuration: TimeInterval = 2.0) {
        self.silenceDuration = silenceDuration
    }

    /// Download and load the VAD model
    /// This can take a few seconds on first run as it downloads the model (~7MB)
    func initialize() async throws {
        do {
            // VadManager handles model downloading internally
            let config = VadConfig(
                defaultThreshold: Self.defaultThreshold,
                debugMode: false,
                computeUnits: .cpuAndNeuralEngine
            )
            vadManager = try await VadManager(config: config)
            streamState = VadStreamState.initial()
            isInitialized = true
        } catch {
            throw VADError.initializationFailed(error)
        }
    }

    /// Process a chunk of audio samples and detect voice activity
    ///
    /// - Parameter samples: 4096 Float samples at 16kHz (256ms)
    /// - Returns: VADResult with voice activity detection result and optional speech events
    /// - Throws: VADError if not initialized or wrong chunk size
    ///
    /// Note: FluidAudio VadManager requires 4096 samples (256ms at 16kHz).
    /// Passing other sizes will be padded/truncated internally, but 4096 is optimal.
    func processChunk(_ samples: [Float]) async throws -> VADResult {
        guard isInitialized, let manager = vadManager, let state = streamState else {
            throw VADError.notInitialized
        }

        // Allow smaller chunks near end of recording, but warn about suboptimal size
        guard samples.count > 0 else {
            throw VADError.invalidChunkSize(
                expected: Self.requiredChunkSize,
                actual: 0
            )
        }

        do {
            let segmentConfig = VadSegmentationConfig(
                minSpeechDuration: 0.15,
                minSilenceDuration: silenceDuration,
                maxSpeechDuration: 30.0,  // Allow up to 30s continuous speech
                speechPadding: 0.1
            )

            let result = try await manager.processStreamingChunk(
                samples,
                state: state,
                config: segmentConfig,
                returnSeconds: false
            )

            // Update state for next chunk
            streamState = result.state

            // Extract speech events
            var speechStart: Int?
            var speechEnd: Int?
            if let event = result.event {
                switch event.kind {
                case .speechStart:
                    speechStart = event.sampleIndex
                case .speechEnd:
                    speechEnd = event.sampleIndex
                }
            }

            return VADResult(
                isVoiceActive: result.state.triggered,
                confidence: result.probability,
                speechStartSample: speechStart,
                speechEndSample: speechEnd
            )
        } catch {
            throw VADError.processingFailed(error)
        }
    }

    /// Reset VAD internal state for a new utterance
    /// Call this when starting a new recording session
    func reset() {
        streamState = VadStreamState.initial()
    }

    /// Update the silence duration threshold
    /// - Parameter duration: Silence duration in seconds (typically 1.0-5.0)
    func setSilenceDuration(_ duration: TimeInterval) {
        silenceDuration = max(0.5, min(5.0, duration))
    }

    /// Get current silence duration setting
    var currentSilenceDuration: TimeInterval {
        silenceDuration
    }
}
