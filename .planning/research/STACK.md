# Stack Research: VoiceType v1.1

**Domain:** macOS Vietnamese Speech-to-Text Enhancement
**Researched:** 2026-01-18
**Milestone:** v1.1 - Smart Dictation
**Confidence:** MEDIUM (some features need validation during implementation)

## Executive Summary

VoiceType v1.0 shipped with WhisperKit (not SwiftWhisper as originally researched). This v1.1 research focuses on four new features that enhance the existing WhisperKit-based stack:

1. **Custom Vocabulary** - WhisperKit's `promptTokens` + post-processing
2. **Auto-translate to English** - Apple Translation framework (offline)
3. **Audio Auto-segmentation** - FluidAudio SileroVAD (CoreML)
4. **Better English detection in Vietnamese** - Multi-strategy approach

All recommendations maintain 100% offline operation.

---

## Feature 1: Custom Vocabulary with Phonetic Hints

**Goal:** Map phonetic Vietnamese pronunciations to English technical terms ("iu-ai" -> "UI", "co-lot" -> "Claude")

### Recommended Approach: Multi-layer Strategy

| Layer | Technology | Purpose | Confidence |
|-------|------------|---------|------------|
| 1. Prompt conditioning | WhisperKit `promptTokens` | Bias model toward vocabulary | MEDIUM |
| 2. Post-processing | Swift string replacement | Guaranteed mapping | HIGH |
| 3. Fallback | Phonetic fuzzy matching | Handle variations | HIGH |

### WhisperKit DecodingOptions for Prompts

```swift
// Current v1.0 code in TranscriptionService.swift
let options = DecodingOptions(
    task: .transcribe,
    language: whisperLanguage,
    temperatureFallbackCount: 3,
    sampleLength: 224,
    usePrefillPrompt: true,
    usePrefillCache: true,
    skipSpecialTokens: true,
    withoutTimestamps: true
)

// v1.1 addition: promptTokens for vocabulary biasing
let vocabularyPrompt = "Technical terms: UI, API, Claude, cursor, TypeScript, React"
let promptTokens = try? whisperKit.tokenizer?.encode(text: vocabularyPrompt)

let options = DecodingOptions(
    task: .transcribe,
    language: whisperLanguage,
    promptTokens: promptTokens,  // NEW: vocabulary bias
    // ... rest same as v1.0
)
```

**Known Issue:** WhisperKit issue #372 reports `promptTokens` can cause empty results with some models. Test thoroughly with large-v3.

**Source:** [WhisperKit Configurations.swift](https://github.com/argmaxinc/whisperkit/blob/main/Sources/WhisperKit/Core/Configurations.swift)

### Post-Processing Replacement (Guaranteed Layer)

```swift
// VocabularyMapper.swift - new service
struct PhoneticMapping {
    let patterns: [String]  // ["iu ai", "iu-ai", "ui", "you eye"]
    let replacement: String // "UI"
}

class VocabularyMapper {
    private let mappings: [PhoneticMapping] = [
        PhoneticMapping(patterns: ["iu ai", "iu-ai", "you eye", "you i"], replacement: "UI"),
        PhoneticMapping(patterns: ["cờ lốt", "cờ-lốt", "claude", "clod"], replacement: "Claude"),
        PhoneticMapping(patterns: ["a pi ai", "a-pi-ai", "api", "ây pi ai"], replacement: "API"),
        PhoneticMapping(patterns: ["typescript", "tai script"], replacement: "TypeScript"),
        // User-configurable mappings loaded from UserDefaults/JSON
    ]

    func apply(to text: String) -> String {
        var result = text.lowercased()
        for mapping in mappings {
            for pattern in mapping.patterns {
                result = result.replacingOccurrences(of: pattern, with: mapping.replacement)
            }
        }
        return result
    }
}
```

### What NOT to Use

| Avoid | Why | Impact |
|-------|-----|--------|
| Fine-tuning Whisper | Requires labeled audio data, training infrastructure | Not practical for custom vocab |
| WhisperKit's Argmax Custom Vocabulary | Enterprise feature, not in open-source SDK | License cost |
| External NLP for vocabulary | Adds latency, complexity | Offline requirement |

### Stack for Custom Vocabulary

| Component | Version | Notes |
|-----------|---------|-------|
| WhisperKit | 0.15.0+ | `promptTokens` in DecodingOptions |
| Custom VocabularyMapper | New service | Post-processing layer |
| UserDefaults or JSON | Built-in | User-configurable mappings |

**Confidence: MEDIUM** - promptTokens effectiveness needs testing; post-processing fallback is HIGH confidence.

---

## Feature 2: Auto-translate Vietnamese to English

**Goal:** Toggle setting to output English text when speaking Vietnamese

### Recommended: Apple Translation Framework

| Criterion | Apple Translation | MarianMT/NLLB | Argos Translate |
|-----------|-------------------|---------------|-----------------|
| Vietnamese support | YES (since iOS 17.4) | Partial | Problematic offline |
| Offline | YES (downloadable packs) | Requires CoreML conversion | Issues reported |
| Integration effort | LOW (native framework) | HIGH (model conversion) | MEDIUM (Python bridge) |
| Quality | Good | Variable | Lower |
| Size | ~150MB language pack | 600MB-2.5GB | ~200MB pair |
| License | Free (Apple devices) | Varies | MIT |

**Recommendation:** Use **Apple Translation framework** because:
1. Native integration with Swift/SwiftUI
2. Offline Vietnamese-English support since iOS 17.4 / macOS 14.4
3. No model conversion needed
4. Maintained by Apple, quality updates automatic

### Apple Translation API Usage

```swift
import Translation

class TranslationService {
    private var configuration: TranslationSession.Configuration?

    func translateToEnglish(_ vietnameseText: String) async throws -> String {
        // Create configuration for Vietnamese -> English
        let config = TranslationSession.Configuration(
            source: Locale.Language(identifier: "vi"),
            target: Locale.Language(identifier: "en")
        )

        // Use TranslationSession for batch translation
        // Note: Requires SwiftUI context for .translationTask modifier
        // For programmatic use, need to handle session lifecycle

        return translatedText
    }

    func checkLanguageAvailability() async -> Bool {
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: Locale.Language(identifier: "vi"),
            to: Locale.Language(identifier: "en")
        )
        return status == .installed
    }
}
```

**Critical Constraint:** Apple Translation requires SwiftUI context (`.translationTask` modifier). For our service-based architecture, we need a hidden SwiftUI view to host the translation session.

### Integration Pattern

```swift
// In TranscriptionService.swift
@MainActor
func stopRecording() async {
    // ... existing transcription code ...

    let text = try await transcribe(samples: samples)

    // NEW: Auto-translate if enabled
    let finalText: String
    if UserDefaults.standard.bool(forKey: "autoTranslateToEnglish") {
        finalText = try await translationService.translateToEnglish(text)
    } else {
        finalText = text
    }

    // ... rest of insertion/history code ...
}
```

### Language Pack Download Flow

```swift
// Check and prompt for download in Settings
func ensureLanguagePacksDownloaded() async {
    let availability = LanguageAvailability()
    let viStatus = await availability.status(
        from: Locale.Language(identifier: "vi"),
        to: Locale.Language(identifier: "en")
    )

    if viStatus == .supported {
        // Need download - show system download UI
        // This triggers automatically on first translation attempt
    }
}
```

### What NOT to Use

| Avoid | Why |
|-------|-----|
| MarianMT / Helsinki-NLP | No pre-built CoreML, requires 600MB+ model, quality variable for Vietnamese |
| NLLB (Meta) | 2.5GB model size, CC-BY-NC license (non-commercial only) |
| Argos Translate | Vietnamese offline support has known issues |
| LibreTranslate | Vietnamese not available in offline version |
| LLM-based translation | Model size, latency, complexity |

### Stack for Translation

| Component | Version | Notes |
|-----------|---------|-------|
| Apple Translation | macOS 14.4+ | `import Translation` |
| LanguageAvailability | Built-in | Check language pack status |
| TranslationSession | Built-in | Programmatic translation |

**Confidence: HIGH** - Apple framework, official Vietnamese support.

**Source:** [Apple Translation Documentation](https://developer.apple.com/documentation/translation/), [WWDC24 Translation API](https://developer.apple.com/videos/play/wwdc2024/10117/)

---

## Feature 3: Audio Auto-segmentation (Silence Detection)

**Goal:** In toggle mode, automatically transcribe and insert when user pauses speaking

### Recommended: FluidAudio with SileroVAD

| Library | Type | Size | Latency | License |
|---------|------|------|---------|---------|
| **FluidAudio** | Swift/CoreML | 1.8MB | <1ms/30ms | Apache 2.0 |
| RealTimeCutVADLibrary | ONNX Runtime | ~5MB | ~2ms | MIT |
| WhisperKit EnergyVAD | Built-in | 0 | Varies | MIT |
| Custom energy threshold | Manual | 0 | Varies | N/A |

**Recommendation:** Use **FluidAudio** because:
1. CoreML-native (runs on ANE, low power)
2. Pre-built Swift package
3. Supports both streaming and offline modes
4. SileroVAD proven accuracy (MIT license)

### FluidAudio Integration

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9"),
]

// VADService.swift
import FluidAudio

class VADService {
    private let manager = AudioManager()
    private var isVADEnabled = false

    // Callback when speech ends (silence detected after speech)
    var onSpeechEnd: (() -> Void)?

    func startStreamingVAD(audioSamples: [Float]) async {
        // Configure VAD thresholds
        let config = VADConfiguration(
            speechProbabilityThreshold: 0.5,  // Confidence threshold
            minSpeechDuration: 0.25,          // Minimum speech length (seconds)
            minSilenceDuration: 0.8           // Silence before triggering end
        )

        // Stream mode for real-time detection
        for try await event in manager.streamVAD(samples: audioSamples, config: config) {
            switch event {
            case .speechStart:
                // User started speaking
                break
            case .speechEnd:
                // User stopped - trigger transcription
                onSpeechEnd?()
            case .probability(let prob):
                // Optional: show confidence indicator
                break
            }
        }
    }
}
```

### Integration with AudioRecorder

```swift
// Modified AudioRecorder.swift for v1.1
class AudioRecorder {
    // ... existing code ...

    private let vadService = VADService()
    var onSilenceDetected: (([Float]) -> Void)?  // NEW: callback for auto-segment

    private func processBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        // ... existing conversion code ...

        accumulatedSamples.append(contentsOf: samples)

        // NEW: Feed to VAD in toggle mode
        if isAutoSegmentEnabled {
            Task {
                await vadService.processSamples(samples)
            }
        }
    }
}
```

### Auto-segment Flow

```
User toggles ON recording
    -> AudioRecorder captures continuously
    -> VADService monitors for silence
    -> On silence detection:
        -> Take accumulated samples since last transcription
        -> Transcribe segment
        -> Insert text
        -> Continue recording
User toggles OFF
    -> Transcribe any remaining samples
    -> Stop recording
```

### Alternative: WhisperKit Built-in VAD

WhisperKit v0.14.0+ exposed `EnergyVAD` publicly. Consider for simpler integration:

```swift
// Using WhisperKit's built-in VAD
let vad = EnergyVAD()
let hasVoice = await vad.voiceActivity(in: samples)
```

However, EnergyVAD is simpler (energy-based, not neural) and may be less accurate than SileroVAD for detecting true speech pauses vs background noise.

### What NOT to Use

| Avoid | Why |
|-------|-----|
| WebRTC VAD | Older GMM-based, less accurate than neural |
| Fixed silence threshold | Fails with varying background noise |
| Timer-based segmentation | Unnatural cuts mid-sentence |

### Stack for Auto-segmentation

| Component | Version | Notes |
|-----------|---------|-------|
| FluidAudio | 0.7.9+ | SileroVAD CoreML |
| silero-vad-coreml | Bundled | 1.8MB model |
| Custom VADService | New | Integration layer |

**Confidence: HIGH** - Well-documented library, CoreML native.

**Source:** [FluidAudio GitHub](https://github.com/FluidInference/FluidAudio), [SileroVAD CoreML](https://huggingface.co/FluidInference/silero-vad-coreml)

---

## Feature 4: Better English Detection in Vietnamese Speech

**Goal:** Improve transcription of English words mixed in Vietnamese speech (code-switching)

### The Problem

Vietnamese speakers commonly mix English technical terms:
- "Em muon build mot **React component** de..."
- "Cai **API endpoint** nay bi **timeout**"

Standard Whisper struggles with code-switching - performance drops 3x on mixed-script language pairs.

### Recommended: Multi-strategy Approach

| Strategy | How | Effectiveness |
|----------|-----|---------------|
| 1. Language hint | Set `language: nil` for auto-detect | MEDIUM |
| 2. Vocabulary bias | Include English terms in promptTokens | MEDIUM |
| 3. Post-processing | Custom vocabulary mapper | HIGH |
| 4. Segment-level detection | Detect English segments, re-transcribe | EXPERIMENTAL |

### Strategy 1: Auto Language Detection

```swift
// Let Whisper auto-detect language per segment
let options = DecodingOptions(
    task: .transcribe,
    language: nil,  // AUTO-DETECT instead of forcing "vi"
    detectLanguage: true,
    // ...
)
```

**Tradeoff:** May sometimes output entire segment in wrong language. Test with real code-switching audio.

### Strategy 2: English Terms in Prompt

```swift
// Include expected English technical terms
let technicalTerms = """
Technical vocabulary: React, TypeScript, API, component, function, async, await,
useState, useEffect, npm, yarn, git, commit, push, pull, merge, branch, deploy,
Claude, Cursor, VSCode, terminal, console, debug, error, warning, null, undefined
"""

let promptTokens = try? whisperKit.tokenizer?.encode(text: technicalTerms)
```

### Strategy 3: Post-processing Enhancement

Extend VocabularyMapper to handle common mis-transcriptions:

```swift
// Common code-switching mis-transcriptions
let codeSwichMappings: [PhoneticMapping] = [
    // React ecosystem
    PhoneticMapping(patterns: ["ri act", "re act", "ri-act"], replacement: "React"),
    PhoneticMapping(patterns: ["com po nent", "com-po-nent"], replacement: "component"),
    PhoneticMapping(patterns: ["yu state", "use tate"], replacement: "useState"),

    // General programming
    PhoneticMapping(patterns: ["a pi", "a-pi", "ay pi"], replacement: "API"),
    PhoneticMapping(patterns: ["git hub"], replacement: "GitHub"),
    PhoneticMapping(patterns: ["type script"], replacement: "TypeScript"),
]
```

### Strategy 4: Segment-level Re-transcription (Experimental)

For advanced implementation, detect likely English segments and re-transcribe:

```swift
// EXPERIMENTAL - complex, may not be worth the effort
func enhanceCodeSwitching(_ initialResult: String) async throws -> String {
    // 1. Use NLLanguageRecognizer to find likely English spans
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(initialResult)

    // 2. For segments with high English confidence, re-transcribe with language: "en"
    // 3. Merge results

    return enhancedResult
}
```

**Note:** This is complex and may introduce more errors. Start with strategies 1-3.

### What NOT to Use

| Avoid | Why |
|-------|-----|
| Fine-tuned code-switching model | No Vietnamese-English model available |
| PhoWhisper | Vietnamese-only, worse for English |
| Separate English/Vietnamese passes | Doubles latency, complex merging |

### Stack for English Detection

| Component | Version | Notes |
|-----------|---------|-------|
| WhisperKit auto-detect | 0.15.0 | `language: nil` |
| NLLanguageRecognizer | Built-in | Segment language detection |
| VocabularyMapper | Custom | Post-processing |

**Confidence: MEDIUM** - Code-switching is an active research area. Test extensively.

**Source:** [Whisper Code-Switching Research](https://arxiv.org/abs/2508.19270), [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)

---

## Combined Stack for v1.1

### New Dependencies

```swift
// Package.swift additions for v1.1
dependencies: [
    // Existing v1.0
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),

    // NEW for v1.1
    .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9"),
]
```

### Framework Imports

```swift
// v1.1 new imports
import Translation          // Apple Translation framework (macOS 14.4+)
import FluidAudio          // SileroVAD for auto-segmentation
import NaturalLanguage     // NLLanguageRecognizer for code-switching
```

### Version Requirements

| Requirement | v1.0 | v1.1 |
|-------------|------|------|
| macOS | 14.0+ | **15.0+** (for Translation) |
| Xcode | 15.0+ | 15.0+ |
| Swift | 5.9+ | 5.9+ |
| WhisperKit | 0.13.0+ | **0.15.0+** (for EnergyVAD) |

> **Note:** Research originally stated macOS 14.4+, but stack verification confirmed Translation framework requires macOS 15.0+ (Sequoia).

### New Services

| Service | Purpose | Dependencies |
|---------|---------|--------------|
| VocabularyMapper | Custom vocab post-processing | None |
| TranslationService | Vi->En translation | Translation framework |
| VADService | Silence detection | FluidAudio |

---

## What NOT to Use (Summary)

| Feature | Avoid | Why | Use Instead |
|---------|-------|-----|-------------|
| Custom vocab | Argmax Enterprise | Paid, closed source | promptTokens + post-processing |
| Translation | MarianMT/NLLB | Large models, complex conversion | Apple Translation |
| Translation | Argos Translate | Vietnamese offline issues | Apple Translation |
| VAD | WebRTC VAD | Less accurate | FluidAudio SileroVAD |
| VAD | Simple energy threshold | Noise sensitive | Neural VAD |
| Code-switching | PhoWhisper | Vietnamese-only model | Whisper multilingual |
| Code-switching | Separate passes | Latency, complexity | Multi-strategy |

---

## Integration Notes

### Existing Architecture Impact

```
v1.0 Flow:
HotkeyService -> TranscriptionService -> WhisperKit -> TextInsertionService

v1.1 Flow (additive):
HotkeyService -> TranscriptionService -> WhisperKit
                                      -> VocabularyMapper (NEW)
                                      -> TranslationService (NEW, optional)
                                      -> TextInsertionService

Audio Flow with VAD:
AudioRecorder -> VADService (NEW) -> triggers TranscriptionService
```

### Settings Additions

```swift
// New UserDefaults keys for v1.1
"autoTranslateToEnglish": Bool    // Enable Vi->En translation
"autoSegmentEnabled": Bool         // Enable silence-based segmentation
"silenceThreshold": Double         // VAD silence duration (seconds)
"customVocabulary": [String: String]  // User-defined mappings
```

### Deployment Size Impact

| Component | Size | Notes |
|-----------|------|-------|
| FluidAudio + SileroVAD | ~2MB | CoreML model included |
| Translation language packs | ~150MB each | Downloaded on-demand by system |
| VocabularyMapper | ~10KB | Pure Swift code |

---

## Sources

### Official Documentation
- [Apple Translation](https://developer.apple.com/documentation/translation/) - TranslationSession API
- [WWDC24: Translation API](https://developer.apple.com/videos/play/wwdc2024/10117/) - iOS 18/macOS 15 features
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) - v0.15.0 release notes

### Libraries
- [FluidAudio](https://github.com/FluidInference/FluidAudio) - Swift VAD SDK
- [silero-vad-coreml](https://huggingface.co/FluidInference/silero-vad-coreml) - CoreML VAD model

### Research
- [Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide) - OpenAI cookbook
- [Whisper Code-Switching Research](https://arxiv.org/abs/2508.19270) - Vietnamese-English phoneme recognition
- [PhoWhisper](https://github.com/VinAIResearch/PhoWhisper) - Vietnamese ASR baseline

### Community
- [WhisperKit Issue #372](https://github.com/argmaxinc/WhisperKit/issues/372) - promptTokens empty result bug
- [SileroVAD](https://github.com/snakers4/silero-vad) - Original VAD model

---
*Stack research for: VoiceType v1.1 - Smart Dictation*
*Researched: 2026-01-18*
*Base stack: WhisperKit 0.15.0, SwiftUI, macOS 14.4+*
