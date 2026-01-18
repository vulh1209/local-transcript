# Project Research Summary

**Project:** VoiceType v1.1 - Smart Dictation
**Domain:** macOS Vietnamese Speech-to-Text Enhancement
**Researched:** 2026-01-18
**Confidence:** MEDIUM

## Executive Summary

VoiceType v1.1 "Smart Dictation" builds on the established v1.0 foundation (WhisperKit, SwiftUI, AVAudioEngine) with four enhancement features: custom vocabulary with phonetic hints, auto-translate Vietnamese to English, auto-segmentation on silence, and better English detection in Vietnamese speech. Research confirms all features are achievable using the existing stack with strategic additions: Apple Translation framework for translation, FluidAudio/SileroVAD for silence detection, and WhisperKit's `promptTokens` plus post-processing for vocabulary biasing.

The recommended approach is **additive pipeline enhancement**. The v1.0 transcription pipeline remains intact; v1.1 features slot in as pre-processing (vocabulary prompts), parallel processing (VAD monitoring), or post-processing (vocabulary replacement, translation). This minimizes risk to working functionality. The critical architectural insight is that post-processing replacement is MORE reliable than model prompting for vocabulary - use both as a two-stage approach, but don't depend solely on `promptTokens`.

Key risks center on three areas: (1) Apple Translation API requires SwiftUI context - cannot instantiate directly in services, (2) WhisperKit `promptTokens` has a known bug (#372) that can return empty results - needs fallback, and (3) code-switching (mixed Vietnamese/English) is a fundamental Whisper limitation - set user expectations and rely on post-processing. The macOS minimum increases from 14.0 to **14.4** for Translation framework support. All features maintain 100% offline operation.

## Key Findings

### Recommended Stack

The v1.1 stack extends v1.0 with minimal new dependencies. Apple's native Translation framework replaces any need for third-party translation models. FluidAudio provides CoreML-native VAD. Post-processing handles vocabulary where model prompting is unreliable.

**Core technologies for v1.1:**
- **WhisperKit 0.15.0+**: Transcription engine with `promptTokens` support for vocabulary biasing
- **Apple Translation (macOS 14.4+)**: Offline Vietnamese-to-English translation via system framework
- **FluidAudio 0.7.9+**: SileroVAD CoreML wrapper for silence detection in toggle mode
- **VocabularyMapper (custom)**: Post-processing text replacement service - guaranteed accuracy
- **NLLanguageRecognizer (built-in)**: Segment-level language detection for code-switching mitigation

**Version requirements:**
- macOS 14.4+ (was 14.0 - Translation framework needs 14.4)
- WhisperKit 0.15.0+ (for EnergyVAD exposure and promptTokens fixes)
- Xcode 15.0+ / Swift 5.9+ (unchanged)

**What NOT to use:**
- MarianMT/NLLB for translation (large models, complex conversion, license issues)
- PhoWhisper for code-switching (Vietnamese-only, worse for English)
- WebRTC VAD (older GMM-based, less accurate than neural)
- Argmax Custom Vocabulary SDK (enterprise paid, closed source)

### Expected Features

**Must have (table stakes):**
- Word list input for custom vocabulary - users expect to add domain terms
- Exact-match post-processing replacement - "claude" -> "Claude" reliably
- Translation toggle in settings - clear on/off for translate mode
- Configurable silence threshold - 1.5-3 second default for auto-segment
- Visual feedback for segment boundaries - users need to know when text will insert

**Should have (differentiators):**
- Phonetic hints to Whisper via `promptTokens` - bias recognition toward vocabulary
- Developer preset vocabulary - built-in terms for "vibe coding" (API, UI, Claude, Cursor)
- Whisper native translation (`.translate` task) - zero extra latency, same model
- VAD-based segmentation using SileroVAD - more accurate than energy threshold
- Smart continuation - if user resumes speaking during finalization, cancel and continue

**Defer (v2+):**
- Phonetic spelling system (IPA input) - complex, unreliable with prompting
- Auto-learning vocabulary - requires ML complexity
- Multiple target languages for translation - English only for developer workflow
- Word-level language detection for code-switching - research-level complexity
- Grammar correction on translation output - requires LLM, breaks offline

### Architecture Approach

Features integrate into the existing pipeline as extension points rather than rewrites. The current flow (Hotkey -> AudioRecorder -> ModelManager -> TextInsertionService) gains four strategic additions: VocabularyManager feeds `promptTokens` to DecodingOptions, VADService monitors audio for silence during toggle mode, PostProcessingPipeline chains text transformations after transcription, and TranslationService optionally translates before insertion.

**New components:**
1. **VocabularyManager** - Store vocabulary, convert to tokens, provide replacement rules
2. **VADService** - Wrap FluidAudio SileroVAD, emit speech/silence events
3. **PostProcessingPipeline** - Chain of TextProcessor protocols (vocabulary replacement, future corrections)
4. **TranslationService** - Apple Translation wrapper (requires SwiftUI bridge pattern)

**Data flow changes:**
```
v1.0:  Audio -> Transcribe -> Insert
v1.1:  Audio -> VAD monitor (parallel) -> Transcribe -> VocabReplace -> (Translate?) -> Insert
```

### Critical Pitfalls

1. **Apple Translation API requires SwiftUI views** - Cannot instantiate `TranslationSession` in services. Must create SwiftUI bridge view to host translation, use async to communicate. Architectural decision required before implementation.

2. **WhisperKit `promptTokens` bug (#372)** - Known to return empty results with some configurations. Must have fallback to transcription without prompts. Test thoroughly with large-v3 model before shipping.

3. **Whisper 224-token prompt limit** - Only first ~50-75 vocabulary words influence transcription. Truncation is silent. Limit vocabulary list size in UI, prioritize frequently mis-transcribed words.

4. **VAD false positives in noisy environments** - Energy-based VAD triggers on keyboard clicks, AC noise. Use SileroVAD (neural) over simple threshold. Implement hangover scheme and minimum speech duration.

5. **Code-switching is fundamentally unsupported** - Whisper is "intended for monolingual audio." Accept this limitation, use post-processing vocabulary replacement as primary mitigation, set user expectations.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Custom Vocabulary
**Rationale:** Foundation for all other features. English detection (Feature 4) depends entirely on vocabulary. Simple integration point (DecodingOptions + post-processing).
**Delivers:** VocabularyManager service, prompt token generation, post-processing replacement, Settings UI for vocabulary list
**Addresses:** Custom vocabulary, phonetic hints, developer preset vocabulary
**Avoids:** Token limit pitfall (cap at 50 words), replacement over-matching (use word boundaries)
**Risk:** MEDIUM - Need to verify `promptTokens` bug status in WhisperKit 0.15.0

### Phase 2: Better English Detection
**Rationale:** Builds directly on Phase 1 vocabulary. No new dependencies, same implementation patterns. High value for target users (developers dictating code).
**Delivers:** Developer vocabulary preset, enhanced DecodingOptions (auto-detect mode, adjusted thresholds), code-switching post-processing rules
**Addresses:** English detection in Vietnamese speech, consistent technical term transcription
**Uses:** VocabularyManager from Phase 1
**Avoids:** Language detection flipping (lock after first detection), hallucination from prompts (keep prompts minimal)
**Risk:** MEDIUM - Effectiveness uncertain, set expectations

### Phase 3: Auto-Translate
**Rationale:** Independent of Phase 1-2. Can test against their output. Verify WhisperKit `.translate` task support first.
**Delivers:** TranslationService wrapper, Settings toggle, Whisper translate task integration, Apple Translation fallback for quality
**Addresses:** Auto-translate Vietnamese to English toggle
**Uses:** Apple Translation framework (macOS 14.4+), WhisperKit DecodingTask.translate
**Avoids:** SwiftUI-only API pitfall (create bridge pattern), language download UX friction (proactive download in Settings)
**Risk:** LOW for Whisper translate, MEDIUM for Apple Translation (SwiftUI constraint)

### Phase 4: Auto-Segmentation
**Rationale:** Most complex feature, touches audio pipeline. Benefit from stable vocabulary/translation first. Can be deferred to v1.2 if timeline requires.
**Delivers:** VADService with FluidAudio, toggle mode enhancement, configurable silence threshold, segment preview before insertion
**Addresses:** Auto-insert on silence in toggle mode
**Uses:** FluidAudio 0.7.9+, SileroVAD CoreML model
**Avoids:** VAD false positives (use neural VAD, hangover scheme), aggressive segmentation (2s default threshold), memory growth (max segment duration 30s)
**Risk:** MEDIUM - Threading concerns, third-party dependency, UX tuning needed

### Phase Ordering Rationale

- **Vocabulary first:** Required by English detection, useful for translation quality (protect vocab from translation), independent of audio pipeline changes
- **English detection second:** Zero new dependencies, direct extension of Phase 1, highest value for developer target audience
- **Translation third:** Independent verification possible, two implementation paths (Whisper native vs Apple Translation) provide flexibility
- **Segmentation last:** Most invasive to audio pipeline, can benefit from all previous features, most likely to need UX iteration

### Research Flags

**Phases needing research during planning:**
- **Phase 1:** Verify WhisperKit 0.15.0 `promptTokens` bug status before implementation
- **Phase 3:** Apple Translation SwiftUI bridging pattern needs prototyping - architectural constraint
- **Phase 4:** FluidAudio integration testing - third-party dependency, may have edge cases

**Phases with standard patterns (skip research-phase):**
- **Phase 2:** Enhancement of Phase 1 patterns, well-documented Whisper prompting techniques
- **Phase 3 (Whisper translate path):** Simple task parameter change, official WhisperKit feature

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Apple frameworks (Translation, NaturalLanguage), verified WhisperKit API |
| Features | MEDIUM | Based on competitor analysis and OpenAI cookbook, not user testing |
| Architecture | HIGH | Additive to verified v1.0 architecture, clear integration points |
| Pitfalls | HIGH | Apple Developer Forums, WhisperKit GitHub issues, documented limitations |

**Overall confidence:** MEDIUM

The core stack decisions are HIGH confidence. Feature effectiveness for code-switching and vocabulary prompting is MEDIUM - these are known hard problems with documented limitations. Mitigation strategies (post-processing) have HIGH confidence of implementation but MEDIUM confidence of user satisfaction.

### Gaps to Address

- **`promptTokens` bug validation:** Must verify current WhisperKit version before Phase 1 implementation - check GitHub issues
- **Apple Translation SwiftUI bridge:** Need to prototype the service-to-SwiftUI communication pattern before Phase 3
- **Vocabulary effectiveness:** Real-world testing needed - prompting may help less than research suggests
- **VAD threshold tuning:** Default parameters from research, actual values need user testing
- **Code-switching expectations:** Must clearly communicate limitations to users - not a solved problem

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) - DecodingOptions API, promptTokens, translate task
- [Apple Translation Documentation](https://developer.apple.com/documentation/translation/) - TranslationSession API
- [FluidAudio GitHub](https://github.com/FluidInference/FluidAudio) - SileroVAD CoreML Swift package
- [OpenAI Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide) - Vocabulary techniques, limitations
- [Superwhisper Vocabulary Docs](https://superwhisper.com/docs/get-started/interface-vocabulary) - Two-stage approach pattern

### Secondary (MEDIUM confidence)
- [WhisperKit Issue #372](https://github.com/argmaxinc/WhisperKit/issues/372) - promptTokens empty result bug
- [Picovoice VAD Guide 2025](https://picovoice.ai/blog/complete-guide-voice-activity-detection-vad/) - VAD implementation patterns
- [WWDC24 Translation API](https://developer.apple.com/videos/play/wwdc2024/10117/) - iOS 18/macOS 15 features
- [Silero VAD GitHub](https://github.com/snakers4/silero-vad) - Original VAD model documentation

### Tertiary (LOW confidence)
- [Whisper Code-Switching Research](https://arxiv.org/abs/2412.16507) - Limitations and adapter approaches
- [Vietnamese-English TSPC Research](https://arxiv.org/abs/2509.05983) - 19.9% WER on code-switching (research benchmark)

---
*Research completed: 2026-01-18*
*Ready for roadmap: yes*
