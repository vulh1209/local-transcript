# Phase 6: Auto-Segment - Research

**Researched:** 2026-01-18
**Domain:** Voice Activity Detection (VAD), Audio Streaming, Async Queue Management
**Confidence:** HIGH

## Summary

This phase adds continuous dictation mode where users can speak without manual hotkey releases. The system automatically detects silence, segments audio, and queues transcriptions for sequential processing.

**Key findings:**
1. **WhisperKit has built-in EnergyVAD** - The project already uses WhisperKit which includes `EnergyVAD` and `AudioStreamTranscriber` for streaming. However, this is energy-threshold based, not neural.
2. **SileroVAD via FluidAudio is the recommended approach** for neural VAD. FluidAudio provides a CoreML-optimized Silero model with Swift bindings, supporting macOS 14+ (our target).
3. **Existing AudioRecorder can be extended** - The current `processBuffer()` tap can feed both the accumulator and VAD detector in parallel.
4. **Swift actors provide clean queue management** - Either custom actor or `swift-async-queue` library for FIFO processing.

**Primary recommendation:** Use FluidAudio's SileroVAD for accurate silence detection (neural beats energy threshold), extend AudioRecorder with a circular buffer, and implement an actor-based transcription queue.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FluidAudio | 0.7.9+ | SileroVAD CoreML | Production-ready VAD for Apple platforms, ANE-optimized |
| swift-async-queue | 1.0.0+ | FIFO task queue | Guaranteed ordering, actor-safe, well-maintained |

### Already in Project
| Library | Version | Purpose | Relevance |
|---------|---------|---------|-----------|
| WhisperKit | current | Transcription | Has built-in EnergyVAD (backup option) |
| AVAudioEngine | system | Audio capture | Already set up, extends naturally |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FluidAudio SileroVAD | WhisperKit EnergyVAD | Energy-based is simpler but less accurate; misses quiet speech, triggers on non-speech noise |
| FluidAudio SileroVAD | Manual CoreML model loading | More control but significant integration work |
| swift-async-queue | Custom Actor | Library is simpler; custom gives more control over queue depth tracking |

**Installation:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9"),
    .package(url: "https://github.com/dfed/swift-async-queue", from: "1.0.0"),
]
```

## Architecture Patterns

### Recommended Project Structure
```
LocalTranscript/
├── Services/
│   ├── AudioRecorder.swift         # MODIFY: Add VAD integration, circular buffer
│   ├── TranscriptionService.swift  # MODIFY: Add continuous mode, queue management
│   ├── VADService.swift            # NEW: Wraps FluidAudio VADManager
│   └── TranscriptionQueue.swift    # NEW: Actor-based FIFO queue
├── Models/
│   ├── SegmentMode.swift           # NEW: Manual vs Auto segment mode
│   └── StatusIndicatorState.swift  # MODIFY: Add queue depth indicator
└── Views/
    └── SettingsView.swift          # MODIFY: Add segment settings
```

### Pattern 1: VAD-Triggered Segmentation Pipeline

**What:** Audio flows through VAD detector continuously; silence triggers segment extraction.

**When to use:** Continuous dictation mode is active.

**Data Flow:**
```
[Mic] --> [AudioRecorder] --> [16kHz Samples]
                |                    |
                v                    v
        [Circular Buffer]     [VAD Detector]
                |                    |
                |      <-- [Silence Detected]
                v
        [Extract Segment] --> [Transcription Queue] --> [Insert Text]
                |
                v
        [Continue Recording]
```

**Example:**
```swift
// VAD integration in AudioRecorder (conceptual)
private func processBuffer(_ inputBuffer: AVAudioPCMBuffer) {
    // 1. Convert to 16kHz as before
    let samples = convertTo16kHz(inputBuffer)

    // 2. Feed to circular buffer
    circularBuffer.append(samples)

    // 3. Feed to VAD detector (512 samples = 32ms chunks)
    for chunk in samples.chunked(into: 512) {
        let result = vadService.processChunk(chunk)
        if result.isSilenceDetected {
            onSilenceDetected?(circularBuffer.extract())
        }
    }
}
```

### Pattern 2: Actor-Based Transcription Queue

**What:** Sequential FIFO processing of audio segments with queue depth tracking.

**When to use:** Multiple segments pending transcription.

**Example:**
```swift
// Source: swift-async-queue pattern
actor TranscriptionQueue {
    private var pendingCount: Int = 0
    private let queue = FIFOQueue()

    var queueDepth: Int { pendingCount }

    func enqueue(samples: [Float]) async -> String {
        pendingCount += 1
        defer { pendingCount -= 1 }

        return await Task(on: queue) {
            try await self.transcribe(samples)
        }.value
    }
}
```

### Pattern 3: Silence Detection State Machine

**What:** Track speech/silence state to avoid over-segmentation.

**States:**
```
IDLE --> [Speech Detected] --> SPEECH --> [Silence Started] --> SILENCE_PENDING
  ^                                              |
  |                              [Silence > threshold]
  |                                              v
  +-------------------------- [Segment Queued] --+
```

**Example:**
```swift
enum VADState {
    case idle
    case speech(startedAt: Date)
    case silencePending(silenceStartedAt: Date, speechSamples: [Float])
}

func processVADResult(_ result: VADResult, currentSamples: [Float]) {
    switch (state, result.isVoiceActive) {
    case (.idle, true):
        state = .speech(startedAt: Date())
    case (.speech, false):
        state = .silencePending(silenceStartedAt: Date(), speechSamples: currentSamples)
    case (.silencePending(let started, let samples), false):
        if Date().timeIntervalSince(started) >= silenceThreshold {
            enqueueForTranscription(samples)
            state = .idle
        }
    case (.silencePending, true):
        // Speech resumed, cancel silence detection
        state = .speech(startedAt: Date())
    default:
        break
    }
}
```

### Anti-Patterns to Avoid
- **Processing VAD on main thread:** VAD runs ~1ms per 32ms chunk but accumulates; keep on audio/background thread
- **Stopping recording between segments:** Keep mic tap running; only extract/clear buffer portions
- **Unbounded queue growth:** Cap queue depth (e.g., 5 segments); show warning if exceeded

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Voice activity detection | Energy threshold comparison | FluidAudio SileroVAD | Neural beats heuristic: handles quiet speech, filters non-speech noise |
| Circular audio buffer | Growing array with manual indexing | TPCircularBuffer pattern | Lock-free, thread-safe, proven in audio apps |
| FIFO task queue | DispatchQueue with manual ordering | swift-async-queue FIFOQueue | Handles async properly, guaranteed ordering |
| Silence duration tracking | Timer-based polling | State machine in VAD callback | More accurate, no timing drift |

**Key insight:** VAD is the critical piece. Energy-based detection (amplitude threshold) fails on: quiet speakers, background music, non-speech noise like typing. SileroVAD was trained on 6000+ languages and handles these cases.

## Common Pitfalls

### Pitfall 1: VAD Chunk Size Mismatch
**What goes wrong:** Passing wrong sample count to SileroVAD causes incorrect probability output.
**Why it happens:** SileroVAD requires exactly 512 samples at 16kHz (32ms chunks).
**How to avoid:** Always chunk audio to 512 samples before VAD processing.
**Warning signs:** Probability always ~0.5, erratic speech detection.

### Pitfall 2: Race Between Buffer Read/Write
**What goes wrong:** Extracting audio for transcription while audio thread is writing causes corruption.
**Why it happens:** `accumulatedSamples` array is not thread-safe.
**How to avoid:** Use lock-free circular buffer or actor isolation for buffer access.
**Warning signs:** Occasional garbled transcriptions, array index crashes.

### Pitfall 3: Over-Segmentation
**What goes wrong:** Every breath/pause creates a new segment, flooding the queue.
**Why it happens:** Silence threshold too short, no minimum speech duration.
**How to avoid:**
- Minimum silence duration: 2s default (user configurable 1-5s per SEG-02)
- Minimum speech duration: 500ms before considering silence
**Warning signs:** Queue depth constantly high, many short transcriptions.

### Pitfall 4: Audio Gap During Transcription
**What goes wrong:** Speech at the moment of segment extraction is lost.
**Why it happens:** Buffer cleared immediately after extraction.
**How to avoid:** Use overlapping/sliding window; keep 200ms of audio after silence detection point.
**Warning signs:** First word of next utterance missing.

### Pitfall 5: Model Download on First VAD
**What goes wrong:** UI freezes or long delay when enabling auto-segment mode.
**Why it happens:** FluidAudio VAD model downloads on first use (~7MB).
**How to avoid:** Pre-download VAD model when user enables auto-segment in settings; show progress indicator.
**Warning signs:** First use of feature hangs for several seconds.

## Code Examples

Verified patterns from official sources:

### FluidAudio VAD Initialization
```swift
// Source: FluidAudio GitHub README
import FluidAudio

class VADService {
    private var manager: VadManager?

    func initialize() async throws {
        let models = try await VadModels.downloadAndLoad()
        manager = VadManager()
        try await manager?.initialize(models: models)
    }

    func processChunk(_ samples: [Float]) async throws -> VADResult {
        // Note: FluidAudio expects 512 samples at 16kHz
        guard let manager = manager else {
            throw VADError.notInitialized
        }
        return try await manager.processStreamingChunk(
            samples,
            config: .default,
            returnSeconds: true
        )
    }
}
```

### SileroVAD Specifications
```swift
// Source: snakers4/silero-vad documentation
// CRITICAL: These values are fixed by the model
let sampleRate = 16000        // Must be 16kHz
let chunkSize = 512           // 512 samples = 32ms
let defaultThreshold = 0.5    // Probability above = speech
let minSilenceDuration = 100  // ms, before silence confirmed
let minSpeechDuration = 250   // ms, before speech confirmed
```

### Swift Circular Buffer Pattern
```swift
// Source: TPCircularBuffer pattern adapted for Swift
class CircularAudioBuffer {
    private var buffer: [Float]
    private var writeIndex = 0
    private var availableCount = 0
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    func write(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }

        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            availableCount = min(availableCount + 1, capacity)
        }
    }

    func read(count: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let readCount = min(count, availableCount)
        let startIndex = (writeIndex - availableCount + capacity) % capacity

        var result = [Float](repeating: 0, count: readCount)
        for i in 0..<readCount {
            result[i] = buffer[(startIndex + i) % capacity]
        }
        return result
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        availableCount = 0
    }
}
```

### FIFO Queue with Depth Tracking
```swift
// Source: swift-async-queue patterns
import AsyncQueue

actor TranscriptionQueueManager {
    private let queue = FIFOQueue()
    private(set) var pendingSegments: Int = 0

    // Observable for UI
    nonisolated var queueDepthPublisher: AsyncStream<Int> {
        AsyncStream { continuation in
            Task {
                for await depth in self.depthUpdates {
                    continuation.yield(depth)
                }
            }
        }
    }

    func enqueue(segment: AudioSegment) async -> TranscriptionResult {
        pendingSegments += 1
        notifyDepthChange()

        defer {
            pendingSegments -= 1
            notifyDepthChange()
        }

        return await Task(on: queue) { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.transcribeSegment(segment)
        }.value
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Energy threshold VAD | Neural VAD (SileroVAD) | 2023 | 10-15% accuracy improvement, handles quiet speech |
| DispatchQueue for async ordering | Swift Concurrency actors | Swift 5.5 (2021) | Cleaner code, better async handling |
| Growing array buffer | Circular buffer | Always been preferred | Bounded memory, no allocation during recording |
| Poll-based silence detection | Event-driven state machine | N/A | More responsive, no timing drift |

**Deprecated/outdated:**
- **webrtc-vad**: Still works but SileroVAD is more accurate for diverse audio conditions
- **onnx-coreml converter**: Deprecated; use coremltools for PyTorch-to-CoreML conversion
- **WhisperKit's EnergyVAD alone**: Good for simple cases but neural VAD recommended for production

## Open Questions

Things that couldn't be fully resolved:

1. **FluidAudio VAD Streaming API Complexity**
   - What we know: FluidAudio has VAD but docs note "APIs are more complicated than they should be"
   - What's unclear: Exact streaming chunk API signature, state management requirements
   - Recommendation: Prototype early; may need to inspect FluidAudio source or use Discord support

2. **WhisperKit + FluidAudio Interaction**
   - What we know: Both use CoreML, both process 16kHz audio
   - What's unclear: Any conflicts running both models simultaneously? Memory pressure?
   - Recommendation: Test on M1 base model (lowest Apple Silicon) for memory constraints

3. **Optimal Silence Threshold UX**
   - What we know: Technical default is 2s, users can configure 1-5s per requirements
   - What's unclear: What threshold works best for Vietnamese vs English speech patterns?
   - Recommendation: A/B test during beta; Vietnamese often has longer pauses between thoughts

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) - VoiceActivityDetector base class, EnergyVAD implementation, AudioStreamTranscriber patterns
- [FluidAudio GitHub](https://github.com/FluidInference/FluidAudio) - VAD API, installation, macOS 14+ requirement
- [snakers4/silero-vad](https://github.com/snakers4/silero-vad) - SileroVAD specifications: 16kHz, 512 samples, threshold defaults

### Secondary (MEDIUM confidence)
- [FluidInference/silero-vad-coreml](https://huggingface.co/FluidInference/silero-vad-coreml) - CoreML model availability, ~7MB total size
- [swift-async-queue](https://github.com/dfed/swift-async-queue) - FIFOQueue API, actor queue patterns
- [TPCircularBuffer](https://atastypixel.com/a-simple-fast-circular-buffer-implementation-for-audio-processing/) - Circular buffer pattern for audio

### Tertiary (LOW confidence)
- FluidAudio VAD "complicated API" note - needs validation during implementation
- SileroVAD performance on M1 - theoretical based on CoreML ANE optimization claims

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - FluidAudio and swift-async-queue are well-documented, production-ready
- Architecture: HIGH - Patterns are standard audio processing approaches
- Pitfalls: MEDIUM - Based on common audio/ML integration issues, may miss Swift-specific edge cases
- FluidAudio API details: LOW - Docs acknowledge API complexity, may need source inspection

**Research date:** 2026-01-18
**Valid until:** 2026-02-18 (30 days - stable libraries)
