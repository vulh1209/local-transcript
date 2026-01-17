# Phase 02: Audio + Transcription - Research

**Researched:** 2026-01-17
**Updated:** 2026-01-17 (WhisperKit migration)
**Domain:** Audio capture (AVAudioEngine), Speech-to-text (WhisperKit), SwiftUI state management
**Confidence:** HIGH

## Summary

This phase implements the complete audio recording and transcription pipeline for Vietnamese speech-to-text. The stack is well-established: AVAudioEngine for microphone capture with AVAudioConverter for 16kHz resampling, **WhisperKit** (Apple's optimized Whisper implementation) for transcription with CoreML acceleration.

**UPDATE (2026-01-17):** Migrated from SwiftWhisper + PhoWhisper to **WhisperKit** for better Apple Silicon optimization and simpler API. WhisperKit automatically downloads models and uses CoreML for fast inference.

The primary technical challenges are:
1. Audio format conversion - AVAudioEngine captures at 44.1/48kHz but Whisper requires 16kHz mono Float32
2. Buffer accumulation - collecting audio during recording, then batch processing
3. State synchronization - recording state must update menu bar icon and floating indicator

**Primary recommendation:** Build a clean AudioRecorder service that accumulates PCM buffers during recording, converts to 16kHz on stop, then passes to existing ModelManager's Whisper instance for transcription.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVAudioEngine | System | Microphone capture | Apple's modern audio API, handles hardware abstraction |
| AVAudioConverter | System | Sample rate conversion | Official API for format conversion, handles edge cases |
| **WhisperKit** | latest | Transcription | Apple-optimized, CoreML acceleration, auto model download |
| whisper-small | CoreML | ASR model | Good balance of speed/accuracy, ~250MB, Vietnamese support |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **NSSound** | System | Audio feedback | For recording start/stop beeps (macOS native) |
| NSPanel | System | Floating window | Recording indicator overlay |

**Note:** AudioToolbox's `AudioServicesPlaySystemSound` IDs (1113, 1114) are iOS-only. Use `NSSound(named:)` on macOS.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AVAudioEngine | AVAudioRecorder | AVAudioRecorder writes to file; we need in-memory buffer for direct transcription |
| Custom conversion | vDSP | More control but AVAudioConverter handles common cases |
| NSPanel | SwiftUI Window | NSPanel has better floating/always-on-top behavior |
| **WhisperKit** | SwiftWhisper | SwiftWhisper wraps whisper.cpp; WhisperKit uses CoreML for Apple Silicon |
| NSHostingView in NSPanel | **Pure AppKit** | SwiftUI's NSHostingView can cause constraint crashes; pure AppKit more stable |

**Installation:**
WhisperKit via Swift Package Manager: `https://github.com/argmaxinc/WhisperKit`

## Architecture Patterns

### Recommended Project Structure
```
LocalTranscript/
├── Services/
│   ├── AudioRecorder.swift       # AVAudioEngine + buffer accumulation
│   ├── TranscriptionService.swift # Coordinates recording -> transcription
│   ├── ModelManager.swift        # Already exists - Whisper instance
│   └── PermissionManager.swift   # Already exists - mic permissions
├── Models/
│   ├── AppState.swift            # Add recording/transcription state
│   └── RecordingState.swift      # State machine for recording
├── Views/
│   ├── MenuBarView.swift         # Update icon based on state
│   ├── FloatingIndicator.swift   # Recording overlay window
│   └── FloatingIndicatorWindow.swift # NSPanel host
```

### Pattern 1: Audio Buffer Accumulation
**What:** Collect audio buffers during recording into an array, convert format on stop
**When to use:** Batch transcription (not real-time streaming)
**Example:**
```swift
// Source: Apple Developer Forums, whisper.cpp discussions
class AudioRecorder {
    private var audioEngine: AVAudioEngine!
    private var audioConverter: AVAudioConverter!
    private var accumulatedBuffers: [AVAudioPCMBuffer] = []

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func startRecording() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Create converter from native -> 16kHz mono
        audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.accumulateBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopRecording() -> [Float] {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Convert and concatenate all buffers
        return convertAccumulatedAudio()
    }
}
```

### Pattern 2: AVAudioConverter for Format Conversion
**What:** Convert each buffer from native format to 16kHz Float32 mono
**When to use:** When tap format doesn't match Whisper requirements
**Example:**
```swift
// Source: GitHub whisper.cpp discussions, Apple Developer Forums
private func convertBuffer(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    let duration = Double(inputBuffer.frameLength) / inputBuffer.format.sampleRate
    let outputFrameCapacity = AVAudioFrameCount(16000 * duration)

    guard let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: targetFormat,
        frameCapacity: outputFrameCapacity
    ) else { return nil }

    var error: NSError?
    audioConverter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
        outStatus.pointee = .haveData
        return inputBuffer
    }

    return outputBuffer
}
```

### Pattern 3: WhisperKit Transcription
**What:** Pass Float array to WhisperKit.transcribe() with Vietnamese language
**When to use:** After recording stops and audio is converted
**Example:**
```swift
// Source: WhisperKit GitHub
func transcribe(audioSamples: [Float]) async throws -> String {
    guard let whisperKit = modelManager.whisperKit else {
        throw TranscriptionError.modelNotLoaded
    }

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

    let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)
    return results.compactMap { $0.text }
        .joined(separator: " ")
        .trimmingCharacters(in: CharacterSet.whitespaces)
}
```

### Pattern 4: Floating NSPanel for Recording Indicator (Pure AppKit)
**What:** Always-on-top window showing recording state
**When to use:** Visual feedback that recording is active
**Example:**
```swift
// Source: Cindori floating panel tutorial (modified for pure AppKit)
// NOTE: Using pure AppKit instead of NSHostingView to avoid SwiftUI constraint crashes
class FloatingIndicatorPanel: NSPanel {
    init() {
        let panelRect = NSRect(x: 0, y: 0, width: 120, height: 36)
        super.init(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        // Pure AppKit content (no SwiftUI NSHostingView)
        let containerView = NSView(frame: panelRect)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        let dotView = NSView(frame: NSRect(x: 16, y: 12, width: 12, height: 12))
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 6
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        containerView.addSubview(dotView)

        let label = NSTextField(labelWithString: "Recording")
        label.frame = NSRect(x: 36, y: 8, width: 70, height: 20)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        containerView.addSubview(label)

        contentView = containerView
    }
}
```

### Anti-Patterns to Avoid
- **Don't use installTap format parameter for conversion:** AVAudioEngine ignores format parameter on input node tap. Must use AVAudioConverter separately.
- **Don't accumulate indefinitely:** Clear buffers on recording stop to prevent memory growth.
- **Don't block main thread during conversion:** Convert buffers in tap callback or use async.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sample rate conversion | Manual resampling with vDSP | AVAudioConverter | Handles fractional rates, anti-aliasing |
| Audio format detection | Hardcode 44.1kHz | inputNode.inputFormat(forBus: 0) | AirPods/USB mics have different rates |
| System beep | Generate sine wave | NSSound.beep() or AudioServicesPlaySystemSound | Respects user volume settings |
| Floating window | SwiftUI Window scene | NSPanel subclass | Better always-on-top, collectionBehavior control |
| Vietnamese punctuation | Post-processing regex | PhoWhisper's built-in | Model trained with punctuation |

**Key insight:** AVAudioEngine and AVAudioConverter handle the messy hardware abstraction. Don't try to assume sample rates or channel counts.

## Common Pitfalls

### Pitfall 1: Assuming Fixed Input Sample Rate
**What goes wrong:** Code hardcodes 44.1kHz but AirPods input at 16kHz, USB mics at 48kHz
**Why it happens:** Developers test only with built-in mic
**How to avoid:** Always query `inputNode.inputFormat(forBus: 0)` at runtime
**Warning signs:** Distorted audio, wrong-speed playback, conversion crashes

### Pitfall 2: installTap Format Parameter Ignored
**What goes wrong:** Passing desired format to installTap doesn't convert the audio
**Why it happens:** Apple docs are unclear; input node doesn't support automatic conversion
**How to avoid:** Always use AVAudioConverter for format conversion
**Warning signs:** Buffer format doesn't match expected format

### Pitfall 3: Buffer Callback on Audio Thread
**What goes wrong:** Heavy processing in tap callback causes dropouts
**Why it happens:** Tap callback runs on real-time audio thread
**How to avoid:** Only append to array in callback; convert later on different queue
**Warning signs:** Audio glitches, missed samples

### Pitfall 4: Memory Growth During Long Recordings
**What goes wrong:** Accumulating buffers for 5+ minute recordings exhausts memory
**Why it happens:** Each buffer is ~4KB, adds up quickly
**How to avoid:** For this app (short dictation), acceptable. For longer, write to disk.
**Warning signs:** Memory warnings, app termination

### Pitfall 5: Menu Bar Icon Not Updating
**What goes wrong:** SF Symbol animation doesn't work in MenuBarExtra
**Why it happens:** MenuBarExtra label is evaluated once, not reactive to state
**How to avoid:** Use @State or @Observable that MenuBarExtra observes; image in label updates
**Warning signs:** Icon stays static during recording

### Pitfall 6: FloatingPanel Disappears Behind Fullscreen Apps
**What goes wrong:** Recording indicator not visible in fullscreen apps
**Why it happens:** Missing collectionBehavior configuration
**How to avoid:** Set `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
**Warning signs:** Indicator vanishes when user is in fullscreen app

## Code Examples

Verified patterns from official sources:

### Complete AudioRecorder Service
```swift
// Source: Synthesized from Apple Developer Forums, whisper.cpp discussions
import AVFoundation

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

    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Verify we can create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterCreationFailed
        }

        audioConverter = converter
        accumulatedSamples = []

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> [Float] {
        guard isRecording, let engine = audioEngine else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        isRecording = false
        audioEngine = nil
        audioConverter = nil

        let samples = accumulatedSamples
        accumulatedSamples = []
        return samples
    }

    private func processBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }

        let duration = Double(inputBuffer.frameLength) / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(16000.0 * duration)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        var inputBufferConsumed = false

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputBufferConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputBufferConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let channelData = outputBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(
                start: channelData,
                count: Int(outputBuffer.frameLength)
            ))
            accumulatedSamples.append(contentsOf: samples)
        }
    }

    enum AudioError: Error {
        case converterCreationFailed
    }
}
```

### Audio Feedback (Start/Stop Beeps)
```swift
// Source: Apple Developer Documentation
// NOTE: AudioServicesPlaySystemSound IDs (1113, 1114) are iOS-only!
// Use NSSound on macOS instead
import AppKit

struct AudioFeedback {
    static func playStartSound() {
        // Use built-in macOS sound names
        if let sound = NSSound(named: "Morse") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    static func playStopSound() {
        if let sound = NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
```

### Dynamic Menu Bar Icon
```swift
// Source: Apple Developer Documentation, Sarunw tutorial
@main
struct LocalTranscriptApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: appState.isRecording ? "waveform.circle.fill" : "waveform")
                .symbolEffect(.pulse, isActive: appState.isRecording)
        }
        .menuBarExtraStyle(.menu)

        // ... other scenes
    }
}
```

### WhisperKit DecodingOptions for Vietnamese
```swift
// Source: WhisperKit GitHub
// Note: WhisperKit uses DecodingOptions instead of WhisperParams

// When calling transcribe, configure for Vietnamese:
let options = DecodingOptions(
    task: .transcribe,
    language: "vi",  // Vietnamese language code
    temperatureFallbackCount: 3,
    sampleLength: 224,
    usePrefillPrompt: true,
    usePrefillCache: true,
    skipSpecialTokens: true,
    withoutTimestamps: true
)

let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AVAudioRecorder to file | AVAudioEngine in-memory | iOS 8+ (2014) | No temp file, direct buffer access |
| SFSpeechRecognizer | Whisper models | 2022+ | Offline, better accuracy |
| SwiftWhisper (whisper.cpp) | **WhisperKit (CoreML)** | 2024+ | Native Apple Silicon optimization |
| StatusItemView AppKit | MenuBarExtra SwiftUI | macOS 13 (2022) | Native SwiftUI menu bar support |
| NSHostingView in NSPanel | Pure AppKit NSPanel | 2026 | Avoids SwiftUI constraint crashes |

**Deprecated/outdated:**
- AVAudioPlayer for recording: Use AVAudioEngine for capture
- Online-only ASR: Whisper-based models work fully offline
- SwiftWhisper: WhisperKit is now recommended for Apple platforms
- AudioServicesPlaySystemSound on macOS: Use NSSound instead (iOS IDs don't work)

## Open Questions

Things that couldn't be fully resolved:

1. **CoreML Acceleration for PhoWhisper**
   - What we know: SwiftWhisper supports CoreML with `-encoder.mlmodelc` file
   - What's unclear: Pre-converted CoreML model availability for PhoWhisper-medium
   - Recommendation: Start with CPU inference (still fast on Apple Silicon), add CoreML later if needed

2. **Optimal Buffer Size**
   - What we know: 4096 samples is common default
   - What's unclear: Best balance between latency and overhead for speech
   - Recommendation: Start with 4096, profile and adjust if needed

3. **System Sound IDs on macOS**
   - What we know: iOS has documented sound IDs, macOS less so
   - What's unclear: Exact IDs for recording start/stop sounds
   - Recommendation: Test 1113/1114, fall back to NSSound.beep() or custom sounds

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) - API usage, model download, CoreML optimization
- [Apple AVAudioEngine Forums](https://developer.apple.com/forums/tags/avaudioengine) - Format conversion patterns
- [Cindori Floating Panel](https://cindori.com/developer/floating-panel) - NSPanel configuration
- [Apple NSSound Documentation](https://developer.apple.com/documentation/appkit/nssound) - Audio feedback

### Secondary (MEDIUM confidence)
- [Sarunw MenuBarExtra Tutorial](https://sarunw.com/posts/swiftui-menu-bar-app/) - Dynamic icon patterns
- [HackingWithSwift SF Symbols](https://www.hackingwithswift.com/quick-start/swiftui/how-to-animate-sf-symbols) - Symbol animations

### Tertiary (LOW confidence - RESOLVED)
- System sound IDs (1113, 1114) - **Confirmed iOS-only, use NSSound on macOS**

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Well-documented Apple APIs + WhisperKit (actively maintained)
- Architecture: HIGH - Pattern synthesized from multiple verified sources
- Pitfalls: HIGH - Common issues documented in Apple Developer Forums
- Audio feedback sounds: HIGH - Confirmed NSSound works on macOS

**Research date:** 2026-01-17
**Updated:** 2026-01-17 (WhisperKit migration, pitfalls verified)
**Valid until:** 2026-02-17 (30 days - stable domain)
