# Architecture Research: VoiceType v1.1

**Domain:** macOS speech-to-text enhancement
**Researched:** 2026-01-18
**Overall Confidence:** HIGH (verified against existing codebase and official documentation)

## Executive Summary

The four v1.1 features integrate cleanly into VoiceType's existing service-oriented architecture. The current pipeline (HotkeyService -> AudioRecorder -> ModelManager -> TextInsertionService) needs strategic extension points rather than rewrites. Key insight: Most features are post-processing transformations that can be layered without touching core transcription.

---

## Feature Analysis

### Feature 1: Custom Vocabulary with Phonetic Hints

**What it does:** Improve recognition of domain-specific terms (names, technical jargon, Vietnamese proper nouns) by providing hint text to Whisper.

**Integration point:** `TranscriptionService.transcribe()` - modify `DecodingOptions`

**How WhisperKit supports this:**
- `DecodingOptions.promptTokens: [Int]?` - tokenized prompt text
- `usePrefillPrompt: Bool` (currently `true` in codebase)
- Prompt conditions the decoder on expected vocabulary

**Architecture approach:**
```
New: VocabularyManager (Service)
     |
     v
TranscriptionService.transcribe()
     |
     +-- Build promptTokens from vocabulary list
     +-- Pass to DecodingOptions
     v
ModelManager.whisperKit.transcribe()
```

**Confidence:** HIGH - WhisperKit explicitly supports `promptTokens` in DecodingOptions. Current code already uses `usePrefillPrompt: true`.

**Caveat:** Known issue (#372) where `promptTokens` can cause empty results in some configurations. Needs testing.

---

### Feature 2: Auto-Translate Vietnamese to English

**What it does:** After transcribing Vietnamese speech, automatically translate to English before insertion.

**Two implementation paths:**

#### Path A: Whisper's Built-in Translation (Recommended)
**Integration point:** `TranscriptionService.transcribe()` - change `DecodingTask`

```swift
// Current (transcribe mode)
DecodingOptions(task: .transcribe, language: "vi", ...)

// Translation mode
DecodingOptions(task: .translate, language: "vi", ...)
// Output: English text directly
```

**Pros:**
- Zero additional latency (happens during inference)
- No extra dependencies
- Works offline

**Cons:**
- Translation quality tied to Whisper model
- Vietnamese -> English only (not bidirectional)

#### Path B: Apple Translation Framework (Post-processing)
**Integration point:** New step after transcription, before text insertion

```
TranscriptionService.transcribe()
     |
     v
TranslationService.translate() [NEW]
     |
     v
TextInsertionService.insertText()
```

**Pros:**
- Better translation quality (Apple's models are newer)
- Potentially bidirectional
- Vietnamese supported as of iOS 26.1 / macOS 26

**Cons:**
- Adds latency (two model runs)
- Requires macOS Tahoe (26+) for Vietnamese
- Language download may be needed

**Recommendation:** Implement Path A first (Whisper's `.translate` task). Add Path B as enhancement later when macOS 26 is widely adopted. Both can coexist as user preference.

**Confidence:** HIGH for Path A (DecodingTask.translate verified in WhisperKit). MEDIUM for Path B (Vietnamese support announced but requires newer OS).

---

### Feature 3: Audio Auto-Segmentation on Silence

**What it does:** Detect pauses in speech to break long recordings into logical segments. Reduces hallucination ("Thank you for listening") during silence.

**Integration point:** `AudioRecorder.processBuffer()` - analyze audio before accumulation

**Two implementation paths:**

#### Path A: Simple Energy-Based Detection
Analyze RMS amplitude in real-time during recording:

```swift
class AudioRecorder {
    private var silenceThreshold: Float = 0.01
    private var silenceDuration: TimeInterval = 0
    private var silenceCallback: ((TimeInterval) -> Void)?

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // Existing conversion code...

        // Add silence detection
        let rms = calculateRMS(samples)
        if rms < silenceThreshold {
            silenceDuration += bufferDuration
            if silenceDuration > 1.5 { // 1.5 seconds
                silenceCallback?(silenceDuration)
            }
        } else {
            silenceDuration = 0
        }
    }
}
```

**Pros:** Zero dependencies, minimal CPU

**Cons:** May trigger on quiet speech, no ML intelligence

#### Path B: SileroVAD Integration (Recommended)
Use ML-based Voice Activity Detection:

```
New: VADService (wraps RealTimeCutVADLibrary or custom)
     |
     v
AudioRecorder.processBuffer()
     |
     +-- Send samples to VADService
     +-- Get voiceStarted/voiceEnded callbacks
     v
TranscriptionService
     +-- On voiceEnded: transcribe segment
     +-- On voiceStarted: start new segment
```

**Library option:** [RealTimeCutVADLibrary](https://github.com/helloooideeeeea/RealTimeCutVADLibrary)
- Swift Package, supports iOS/macOS
- Uses SileroVAD v5 via ONNX Runtime
- 16kHz sample rate supported (matches our pipeline)
- Delegates: `voiceStarted()`, `voiceEnded(withWavData:)`

**Recommendation:** Start with Path A (energy-based) for v1.1 MVP. Graduate to Path B (SileroVAD) if false positives are problematic.

**Confidence:** HIGH for Path A (standard DSP). MEDIUM for Path B (third-party dependency, needs integration testing).

---

### Feature 4: Better English Detection in Vietnamese Speech

**What it does:** Handle code-switching where Vietnamese speakers mix English words/phrases.

**Challenge:** Whisper struggles with intra-sentence language switching. Research shows 4-7% improvement with specialized adapters, but those require model fine-tuning.

**Practical approaches for on-device:**

#### Approach A: Auto-Detect Mode Enhancement
Current code uses `language: nil` for auto-detect. Whisper will try to detect language per-segment.

Enhancement: Lower `noSpeechThreshold` and adjust temperature to be more permissive with mixed content.

```swift
DecodingOptions(
    task: .transcribe,
    language: nil,  // Auto-detect
    temperature: 0.2,  // Slightly higher for variety
    noSpeechThreshold: 0.4,  // Lower threshold
    // ...
)
```

#### Approach B: Vocabulary Prompting (synergy with Feature 1)
Include common English technical terms in the prompt to bias toward recognizing them:

```
Prompt: "Toi dang su dung iPhone, MacBook, GitHub, Xcode..."
```

This conditions the decoder to expect English terms in Vietnamese speech.

#### Approach C: Post-Processing Correction
Use a text correction pass to fix commonly misrecognized English terms:

```
Input: "Toi dang code o Xi-cot"
Output: "Toi dang code o Xcode"
```

This could leverage Apple's Foundation Models Framework (iOS 26+) or a simple dictionary lookup.

**Recommendation:** Implement Approach A + B together. They're low-effort enhancements to existing flow. Approach C is optional for polish.

**Confidence:** MEDIUM - Code-switching is a known hard problem. These mitigations help but won't fully solve it without model fine-tuning.

---

## New Components Needed

| Component | Purpose | Depends On |
|-----------|---------|------------|
| `VocabularyManager` | Store/load custom vocabulary, convert to tokens | ModelManager (for tokenizer) |
| `TranslationService` | Apple Translation framework wrapper | None (optional feature) |
| `VADService` | Voice activity detection wrapper | AudioRecorder |
| `PostProcessingPipeline` | Chain of text transformations | TranscriptionService output |

### Component Boundaries

```
+-------------------------------------------------------------+
| AppState                                                     |
|  +-- VocabularyManager [NEW]                                |
|  +-- AudioRecorder ----------+-- VADService [NEW]           |
|  +-- ModelManager            |                               |
|  +-- TranscriptionService ---+-- PostProcessingPipeline [NEW]|
|  |   +-- uses VocabularyManager                             |
|  +-- TranslationService [NEW - optional]                    |
|  +-- TextInsertionService                                   |
+-------------------------------------------------------------+
```

---

## Data Flow Changes

### Current Flow (v1.0)
```
Hotkey Press
    |
    v
AudioRecorder.startRecording()
    |
    v
[accumulate samples]
    |
    v
Hotkey Release
    |
    v
AudioRecorder.stopRecording() -> [Float]
    |
    v
TranscriptionService.transcribe(samples)
    |
    +-- DecodingOptions(task: .transcribe, language: mode)
    |
    v
ModelManager.whisperKit.transcribe()
    |
    v
TextInsertionService.insertText(text)
    |
    v
HistoryManager.save()
```

### Enhanced Flow (v1.1)
```
Hotkey Press
    |
    v
AudioRecorder.startRecording()
    |
    v
[accumulate samples]
    |
    +-- VADService.processAudioData() [NEW - Feature 3]
    |   |
    |   +-- onSilenceDetected: mark segment boundary
    |
    v
Hotkey Release
    |
    v
AudioRecorder.stopRecording() -> [Float] or [[Float]] segments
    |
    v
TranscriptionService.transcribe(samples)
    |
    +-- VocabularyManager.getPromptTokens() [NEW - Feature 1]
    |
    +-- DecodingOptions(
    |       task: .transcribe OR .translate,  [Feature 2]
    |       language: mode,
    |       promptTokens: vocabularyTokens,   [Feature 1]
    |       noSpeechThreshold: 0.4            [Feature 4]
    |   )
    |
    v
ModelManager.whisperKit.transcribe()
    |
    v
PostProcessingPipeline [NEW]
    |
    +-- TextCorrectionStep [Feature 4 - optional]
    +-- TranslationStep [Feature 2 - if using Apple Translation]
    |
    v
TextInsertionService.insertText(processedText)
    |
    v
HistoryManager.save()
```

---

## Build Order (Dependency Analysis)

Features have these dependencies:

```
Feature 1 (Vocabulary) -------------------------+
    |                                           |
    | provides promptTokens                     |
    v                                           |
Feature 4 (English Detection) ------------------+
    |                                           |
    | uses vocabulary prompting                 |
    v                                           |
Feature 2 (Translation) ------------------------+
    |                                           |
    | translation runs after transcription      |
    | can use same pipeline                     |
    v                                           |
Feature 3 (Segmentation) -----------------------+
    |
    | independent of others
    | but benefits from all above
    v
[All features complete]
```

### Recommended Phase Order

**Phase 1: Custom Vocabulary (Feature 1)**
- Reason: Foundation for Feature 4, simplest integration
- Components: VocabularyManager
- Risk: LOW - Well-documented WhisperKit API

**Phase 2: English Detection (Feature 4)**
- Reason: Builds on Phase 1, no new dependencies
- Components: Enhanced DecodingOptions, optional PostProcessingPipeline
- Risk: MEDIUM - Effectiveness uncertain without testing

**Phase 3: Auto-Translation (Feature 2)**
- Reason: Independent, can test against Phase 1+2 output
- Components: TranslationService (optional), DecodingTask change
- Risk: LOW for Whisper translate, MEDIUM for Apple Translation (OS requirement)

**Phase 4: Silence Segmentation (Feature 3)**
- Reason: Most complex, touches audio pipeline
- Components: VADService, AudioRecorder modifications
- Risk: MEDIUM - Threading concerns, third-party dependency

---

## Technical Risks

### HIGH Risk
None identified - all features have viable implementation paths.

### MEDIUM Risk
1. **promptTokens empty result bug** (Feature 1)
   - Mitigation: Test with different model sizes, have fallback to no-prompt mode

2. **Code-switching accuracy** (Feature 4)
   - Mitigation: Set user expectations, provide manual language override

3. **SileroVAD integration** (Feature 3)
   - Mitigation: Start with simple energy-based detection, upgrade later

### LOW Risk
1. **DecodingTask.translate quality** (Feature 2)
   - Mitigation: Let users choose transcribe vs translate mode

2. **Apple Translation OS requirement** (Feature 2 Path B)
   - Mitigation: Feature-flag behind OS version check

---

## Architecture Patterns to Follow

### Pattern 1: Pipeline Extension
Add new processing steps as composable units:

```swift
protocol TextProcessor {
    func process(_ text: String) async throws -> String
}

class PostProcessingPipeline {
    var processors: [TextProcessor] = []

    func process(_ text: String) async throws -> String {
        var result = text
        for processor in processors {
            result = try await processor.process(result)
        }
        return result
    }
}
```

### Pattern 2: Feature Flags
Use UserDefaults for optional features:

```swift
@ObservationIgnored
var isTranslationEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "translationEnabled") }
}
```

### Pattern 3: Graceful Degradation
Features should fail gracefully:

```swift
func transcribe(samples: [Float]) async throws -> String {
    let vocabularyTokens = vocabularyManager?.getPromptTokens() ?? nil
    // Continue without vocabulary if manager unavailable
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Tight Coupling of Features
**Bad:** Making Feature 4 require Feature 1 to function at all.
**Good:** Each feature works independently, but they enhance each other when combined.

### Anti-Pattern 2: Blocking Audio Thread
**Bad:** Running VAD ML inference on the audio callback thread.
**Good:** Buffer samples, run VAD on separate queue.

### Anti-Pattern 3: Global State for Vocabulary
**Bad:** Static vocabulary list that can't be customized per-user.
**Good:** VocabularyManager as service in AppState, persisted per-user.

---

## Sources

### WhisperKit Documentation
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)
- [DecodingOptions Configuration](https://github.com/argmaxinc/whisperkit/blob/main/Sources/WhisperKit/Core/Configurations.swift)
- [WhisperKit Translation Issue #357](https://github.com/argmaxinc/WhisperKit/issues/357)

### Voice Activity Detection
- [RealTimeCutVADLibrary](https://github.com/helloooideeeeea/RealTimeCutVADLibrary) - iOS/macOS VAD with SileroVAD
- [SileroVAD GitHub](https://github.com/snakers4/silero-vad)
- [WhisperX VAD Integration](https://github.com/m-bain/whisperX)

### Apple Translation
- [Swift Translation API](https://www.polpiella.dev/swift-translation-api/)
- [iOS 26 Vietnamese Support](https://www.macrumors.com/2025/09/22/ios-26-1-apple-intelligence-languages/)

### Code-Switching Research
- [Whisper Code-Switching Limitations](https://arxiv.org/abs/2412.16507)
- [Vietnamese-English Cross-Lingual Recognition](https://arxiv.org/abs/2508.19270)

### Whisper Prompting
- [OpenAI Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide)
- [prompt vs prefix Discussion](https://github.com/openai/whisper/discussions/117)
