# Phase 5: Auto-Translate - Research

**Researched:** 2026-01-18
**Domain:** Speech-to-Text Translation (Vietnamese to English)
**Confidence:** HIGH

## Summary

This phase adds auto-translate capability: user speaks Vietnamese, receives English text output. Research confirms two viable paths, with Whisper's built-in `.translate` task as the clear primary choice.

**Whisper's `.translate` task** is the optimal approach: it performs speech-to-English translation in a single inference pass with no additional latency over transcription. This is a native Whisper capability, not a post-processing step. The translate task was trained alongside transcribe, supporting all 99 Whisper languages as sources.

**Apple Translation framework** could serve as a quality fallback but has significant constraints: requires SwiftUI view context (cannot run headlessly), requires macOS 15+, and requires user to download language packs. Given Whisper's built-in translate capability, this fallback is likely unnecessary.

**Primary recommendation:** Use WhisperKit's `DecodingTask.translate` as the sole translation path. Add a simple "Translate to English" toggle in Settings. This requires no additional dependencies, no macOS version bump, and adds zero latency.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WhisperKit | Current | Speech-to-text with built-in translate | Already integrated, `.translate` task native |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Apple Translation | macOS 15+ | Text-to-text translation | NOT RECOMMENDED - complexity vs value |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Whisper translate | Apple Translation | Requires macOS 15+, SwiftUI bridge, language downloads |
| Whisper translate | External API | Breaks offline requirement |
| Whisper translate | Local LLM | Massive complexity, latency, model size |

**Installation:**
No new dependencies required. WhisperKit already in project.

## Architecture Patterns

### Recommended Project Structure
No structural changes needed. Modify existing files:

```
LocalTranscript/
├── Models/
│   ├── TranslationMode.swift     # NEW: on/off enum
│   └── LanguageMode.swift        # Unchanged
├── Services/
│   └── TranscriptionService.swift # MODIFY: add translate task option
└── Views/
    └── SettingsView.swift         # MODIFY: add translate toggle
```

### Pattern 1: Task Selection at Transcription Time
**What:** Choose `.transcribe` or `.translate` based on user setting at decode time
**When to use:** When calling `whisperKit.transcribe()`
**Example:**
```swift
// Source: WhisperKit Configurations.swift
let options = DecodingOptions(
    task: translateEnabled ? .translate : .transcribe,
    language: whisperLanguage,  // Source language hint (nil for auto-detect)
    // ... other options
)
let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
```

### Pattern 2: Simple UserDefaults Toggle
**What:** Store translate mode preference like existing languageMode
**When to use:** For settings persistence
**Example:**
```swift
// Match existing pattern in TranscriptionService.swift
@ObservationIgnored
private var translateMode: Bool {
    get { UserDefaults.standard.bool(forKey: "translateMode") }
    set { UserDefaults.standard.set(newValue, forKey: "translateMode") }
}
```

### Anti-Patterns to Avoid
- **Two-step transcribe-then-translate:** Whisper's translate is single-pass, don't add latency
- **Apple Translation bridge for Whisper output:** Unnecessary complexity, no quality benefit
- **Language forcing with translate:** Let Whisper auto-detect source; translate target is always English

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vietnamese to English | Post-processing translation pipeline | WhisperKit `.translate` task | Built-in, single inference, zero latency |
| Language detection | Manual language check before translate | Whisper auto-detection | Whisper handles this during decode |
| Translation quality check | Custom validation | User toggle for translate mode | Let user choose when to translate |

**Key insight:** Whisper was trained to do both transcribe AND translate. The translate task is first-class, not a hack. Using it is simpler and faster than any post-processing approach.

## Common Pitfalls

### Pitfall 1: Thinking Translate Adds Latency
**What goes wrong:** Developer assumes translate = transcribe + translation step
**Why it happens:** Mental model of "do X then do Y"
**How to avoid:** Understand Whisper's translate task is a parallel training objective, not post-processing
**Warning signs:** Searching for translation APIs, considering async pipelines

### Pitfall 2: Apple Translation Framework Complexity
**What goes wrong:** Trying to use Apple Translation for better quality
**Why it happens:** Apple's framework seems "official"
**How to avoid:** Remember constraints: SwiftUI-only, macOS 15+, language downloads
**Warning signs:** `TranslationSession`, `.translationTask`, macOS version bumps

### Pitfall 3: Translate Mode Breaking Language Mode
**What goes wrong:** User sets Vietnamese mode + translate, expects Vietnamese output
**Why it happens:** Translate always outputs English regardless of source language setting
**How to avoid:** Make UI clear: "Translate to English" toggle, explain behavior
**Warning signs:** User confusion about why Vietnamese mode outputs English

### Pitfall 4: Disabling Translate for English Input
**What goes wrong:** User speaks English with translate mode on, gets garbled output
**Why it happens:** Whisper tries to "translate" English to English
**How to avoid:** Auto-disable translate when language mode is English; or let it pass through
**Warning signs:** Testing only with Vietnamese, not edge cases

## Code Examples

Verified patterns from official sources:

### Setting Up DecodingOptions for Translation
```swift
// Source: WhisperKit Configurations.swift
// task: DecodingTask - defaults to .transcribe
// "Whether to perform X->X speech recognition ('transcribe') or
//  X->English translation ('translate')"

let options = DecodingOptions(
    task: .translate,           // Key change for translation
    language: nil,              // nil = auto-detect source language
    temperatureFallbackCount: 3,
    sampleLength: 224,
    usePrefillPrompt: true,
    usePrefillCache: true,
    skipSpecialTokens: true,
    withoutTimestamps: true
)
```

### Conditional Task Selection
```swift
// Source: Existing TranscriptionService pattern
private func transcribe(samples: [Float]) async throws -> String {
    guard let whisperKit = modelManager.whisperKit else {
        throw TranscriptionError.modelNotLoaded
    }

    let mode = LanguageMode(rawValue: languageMode) ?? .auto
    let whisperLanguage = mode.whisperLanguageCode

    // Determine task based on translate setting
    let task: DecodingTask = translateMode ? .translate : .transcribe

    let options = DecodingOptions(
        task: task,
        language: whisperLanguage,
        // ... existing options
    )

    let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
    // ... existing result handling
}
```

### Settings Toggle
```swift
// Source: Existing SettingsView pattern
@AppStorage("translateMode") private var translateMode = false

Section("Translation") {
    Toggle("Translate to English", isOn: $translateMode)

    Text("When enabled, Vietnamese speech will be translated to English text.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Transcribe + translate API | Whisper native translate | Whisper v1 (2022) | Single-pass translation |
| Google/DeepL translation | On-device Whisper translate | WhisperKit launch (2024) | Offline capability |

**Deprecated/outdated:**
- **Post-processing translation:** Whisper translate makes this unnecessary
- **Cloud translation APIs:** Violates offline requirement

## Open Questions

Things that couldn't be fully resolved:

1. **Whisper translate quality for Vietnamese specifically**
   - What we know: Whisper supports 99 languages, Vietnamese included
   - What's unclear: Quality compared to transcribe-then-Apple-translate pipeline
   - Recommendation: Start with Whisper translate, gather user feedback, add fallback only if needed

2. **Behavior when language mode is English + translate enabled**
   - What we know: Translate always targets English
   - What's unclear: Does English->English translate degrade quality?
   - Recommendation: Disable translate toggle when language mode is English, or test and document

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub - Configurations.swift](https://github.com/argmaxinc/whisperkit/blob/main/Sources/WhisperKit/Core/Configurations.swift) - DecodingTask enum, task parameter docs
- [WhisperKit GitHub - README](https://github.com/argmaxinc/WhisperKit) - API overview, translate endpoint
- [WhisperKit Issue #357](https://github.com/argmaxinc/WhisperKit/issues/357) - CLI translate usage

### Secondary (MEDIUM confidence)
- [Apple Translation Documentation](https://developer.apple.com/documentation/translation/) - Framework overview (JS blocked, cross-verified)
- [polpiella.dev Translation API](https://www.polpiella.dev/swift-translation-api/) - TranslationSession constraints
- [mjtsai.com Translation API analysis](https://mjtsai.com/blog/2024/07/04/translation-api-in-ios-17-and-macos-sequoia/) - SwiftUI-only limitation

### Tertiary (LOW confidence)
- WebSearch results on Whisper Vietnamese quality - No authoritative benchmarks found

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - WhisperKit translate is documented, verified in source
- Architecture: HIGH - Minimal change to existing patterns
- Pitfalls: MEDIUM - Based on API constraints and logical analysis
- Quality: LOW - No Vietnamese-specific translate benchmarks found

**Research date:** 2026-01-18
**Valid until:** 60 days (stable WhisperKit API, no major changes expected)
