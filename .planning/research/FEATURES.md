# Features Research: VoiceType v1.1

**Domain:** macOS Vietnamese Speech-to-Text Enhancement
**Researched:** 2026-01-18
**Confidence:** MEDIUM (based on WebSearch verified against official sources)

---

## 1. Custom Vocabulary with Phonetic Hints

**Goal:** Allow users to teach the app words like "iu-ai" -> "UI", "cờ-lốt" -> "Claude"

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Word list input** | Users need to add custom terms | LOW | Simple list UI in settings |
| **Exact match replacement** | "claude" should become "Claude" consistently | LOW | Post-transcription string replacement |
| **Case preservation** | Maintain capitalization rules | LOW | Superwhisper does case-insensitive matching with specified output case |
| **Persistence** | Vocabulary saved between sessions | LOW | UserDefaults or JSON file |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Phonetic hints to model** | Pass vocabulary to Whisper's initial_prompt for better recognition | MEDIUM | WhisperKit supports `prompt` parameter. Limited to 224 tokens. |
| **Two-stage approach** | AI hints + post-processing replacement | MEDIUM | Superwhisper pattern: vocabulary words guide transcription, replacements fix remaining errors |
| **Import/export vocabulary** | Share vocabulary across devices or users | LOW | JSON export/import |
| **Developer preset vocabulary** | Built-in terms for "vibe coding" (API, UI, CLI, Claude, Cursor, GitHub) | LOW | High value for target audience |
| **Multiple replacement targets** | "iu-ai", "you-ai", "UI" all map to "UI" | LOW | Handle common misrecognitions |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Phonetic spelling system** | Complex IPA input is intimidating; Whisper prompting is unreliable for phonetics | Use text hints ("iu-ai") directly; rely on post-processing replacement |
| **Auto-learning vocabulary** | Requires ML complexity; inconsistent results | Manual vocabulary management; let users explicitly add words |
| **Unlimited vocabulary size** | Too many words confuse Whisper model; 224 token limit for prompts | Recommend max 20-50 words; warn users about diminishing returns |
| **Per-app vocabulary** | Over-engineering; users rarely need this | Single global vocabulary; let users manage manually |

### Implementation Notes

**Whisper Prompt Approach (HIGH confidence - official docs):**
- Pass custom vocabulary as "glossary" in initial_prompt: `"Glossary: Claude, UI, GitHub, Cursor"`
- Whisper uses this to bias spelling but not guaranteed
- Only first 224 tokens of prompt are used
- Per OpenAI Cookbook: "These techniques are not especially reliable, but can be useful in some situations"

**Post-Processing Approach (HIGH confidence - Superwhisper docs):**
- Programmatic string replacement after transcription
- Case-insensitive matching, specified output case
- 100% reliable for exact matches
- Superwhisper recommends using BOTH: vocabulary for AI hints, replacements for consistency

**Recommended Architecture:**
1. Vocabulary words -> sent to WhisperKit prompt parameter
2. Replacements -> post-processing after transcription
3. Same UI can configure both (word -> replacement mapping)

### Sources

- [OpenAI Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide) - Official prompting techniques
- [Superwhisper Vocabulary Docs](https://superwhisper.com/docs/get-started/interface-vocabulary) - Two-stage approach
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) - Prompt parameter support
- [Argmax Custom Vocabulary](https://www.argmaxinc.com/blog/whisperkit) - Enterprise SDK feature

---

## 2. Auto-Translate Vietnamese to English

**Goal:** Toggle in settings; speak Vietnamese, output English text

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Translation toggle** | Clear on/off in settings or menu bar | LOW | Simple boolean setting |
| **Offline operation** | Must work without internet | HIGH | Requires local translation model or Whisper's built-in translation |
| **Quality threshold** | Output should be usable, not perfect | MEDIUM | Developer dictation tolerance for imperfect translation |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Whisper native translation** | Whisper has built-in transcribe-to-English task | LOW | Already supported in Whisper; translate vs transcribe task |
| **Per-transcription toggle** | Switch between transcribe/translate on the fly | LOW | Menu bar quick toggle |
| **Show original + translation** | Display both in history for verification | LOW | Useful for learning or verification |
| **Translation quality indicator** | Confidence score or "rough translation" label | MEDIUM | Set expectations appropriately |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Cloud translation API** | Breaks offline requirement; privacy concerns | Use Whisper's native translation task |
| **Post-transcription translation** | Two-step adds latency and error compounding | Single-step Whisper translation |
| **Multiple target languages** | Over-engineering for target audience | English only (developer workflow focus) |
| **Real-time translation display** | Distracting; Whisper processes full audio | Show result after completion |
| **Grammar correction on translation** | Requires additional LLM; breaks offline | Accept Whisper's raw translation output |

### Implementation Notes

**Whisper Translation Task (HIGH confidence - official Whisper):**
- Whisper natively supports `task: translate` which outputs English regardless of input language
- Same model, different decoding task
- Quality varies by language; Vietnamese-to-English is reasonably good for conversational content
- Per OpenAI: "Whisper can translate speech from any language to English"

**WhisperKit Implementation:**
- Need to verify WhisperKit exposes the translate task (vs transcribe-only)
- If supported, simply toggle task parameter
- If not supported, would need alternative approach (OUT OF SCOPE for offline)

**Quality Expectations:**
- Translation is functional, not literary
- Good for: developer notes, AI prompts, technical content
- Weak for: idiomatic expressions, cultural nuance
- Set user expectations appropriately in UI

### Sources

- [OpenAI Whisper](https://github.com/openai/whisper) - Translation task documentation
- [Whisper Paper](https://openai.com/index/whisper/) - Multilingual and translation capabilities
- [Soniox Vietnamese Translation](https://soniox.com/speech-to-text/vietnamese) - Competitive reference

---

## 3. Audio Auto-Segmentation on Silence

**Goal:** In toggle mode, auto-insert text when user pauses; don't wait for manual stop

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Silence threshold** | Configurable pause duration to trigger insertion | LOW | 1.5-3 seconds typical |
| **Natural pause detection** | Don't segment mid-sentence on brief pauses | MEDIUM | VAD + timing heuristics |
| **Visual feedback** | Show when segment is about to be finalized | LOW | Countdown or indicator |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **VAD-based segmentation** | Use actual voice activity detection, not just volume | MEDIUM | WhisperKit includes VAD; Silero VAD is industry standard |
| **Configurable threshold** | Let users tune pause duration (1-5 seconds) | LOW | Slider in settings |
| **Smart continuation** | If user resumes speaking during finalization, cancel and continue | MEDIUM | Better UX for natural speech patterns |
| **Segment preview** | Show pending text before insertion, allowing cancel | MEDIUM | Review buffer before commit |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Aggressive segmentation** | Segments mid-sentence on natural pauses; frustrating | Use longer default threshold (2-3 seconds); bias toward completion |
| **No manual override** | Users sometimes want to pause and think | Keep manual stop hotkey always available |
| **Auto-send after segment** | Dangerous; user should review before submission | Auto-insert to text field only; never auto-submit forms |
| **Complex VAD tuning UI** | Overwhelming for users | Simple slider (1-5 seconds); hide technical details |
| **Word-level streaming** | Distracting; increases complexity | Full-segment insertion after silence |

### Implementation Notes

**VAD Options (HIGH confidence - verified):**

1. **WhisperKit Built-in VAD:**
   - WhisperKit advertises "voice activity detection" as a feature
   - Need to verify API exposure for custom threshold control

2. **Silero VAD (MEDIUM confidence - widely used):**
   - Industry standard, 1.8MB model, ~1ms per 30ms chunk
   - Parameters: `positiveSpeechThreshold` (0.5), `negativeSpeechThreshold` (0.35)
   - Can be layered on top of WhisperKit audio pipeline

**Recommended Parameters:**
- Default silence threshold: 2.0 seconds
- Minimum valid segment: 0.5 seconds (avoid noise triggers)
- Pre-speech padding: 300ms (capture word starts)
- User-configurable range: 1.0 - 5.0 seconds

**UX Flow:**
1. User activates toggle mode
2. Audio continuously captured and analyzed by VAD
3. When speech detected, start segment
4. When silence exceeds threshold, finalize segment
5. Show brief "inserting..." indicator
6. Transcribe and insert segment
7. Continue listening for next segment
8. Manual stop hotkey ends session

### Sources

- [Picovoice VAD Guide 2025](https://picovoice.ai/blog/complete-guide-voice-activity-detection-vad/) - Comprehensive VAD overview
- [Silero VAD GitHub](https://github.com/snakers4/silero-vad) - Implementation reference
- [Deepgram Endpointing](https://developers.deepgram.com/docs/understanding-end-of-speech-detection) - Speech-to-silence detection patterns
- [WhisperX VAD](https://deepwiki.com/m-bain/whisperX/4.1-voice-activity-detection) - VAD + Whisper integration

---

## 4. Better English Detection in Vietnamese Speech

**Goal:** Improve transcription of English words when speaking Vietnamese (code-switching)

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Handle common English words** | "GitHub", "Claude", "API" should transcribe correctly | MEDIUM | Use vocabulary prompting for common terms |
| **Preserve English spelling** | Don't convert English to Vietnamese phonetics | MEDIUM | Whisper multilingual should handle this |
| **Consistent behavior** | Same word should transcribe the same way each time | MEDIUM | Harder than it sounds with code-switching |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Developer vocabulary preset** | Pre-loaded terms for coding: API, CLI, UI, GitHub, npm, etc. | LOW | High value for target audience |
| **Prompt engineering for mixed speech** | Include English terms in prompt to bias recognition | LOW | "Common terms: GitHub, Claude, API, npm, React, TypeScript" |
| **Post-processing for known terms** | Fix common misrecognitions | LOW | "git hub" -> "GitHub", "a.p" -> "API" |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Automatic language switching** | Unreliable; causes errors in both languages | Stay in Vietnamese mode; use vocabulary hints |
| **Word-level language detection** | Very hard problem; research-level complexity | Treat as Vietnamese with English vocabulary |
| **Dual-model approach** | Run both Vietnamese and English models | Single multilingual Whisper with prompting |
| **Real-time language detection** | Adds latency; error-prone | Use consistent mode throughout segment |

### Implementation Notes

**The Challenge (MEDIUM confidence - research):**
- Vietnamese-English code-switching is an active research area
- Recent paper (TSPC 2025): 19.9% WER on Vietnamese-English code-switching
- Challenge: "both distinct phonological features and ambiguity from similar sound recognition"
- No production-ready solution for true code-switching

**Practical Approach for v1.1:**
1. **Vocabulary prompting:** Include common English terms in Whisper prompt
2. **Post-processing:** String replacement for known terms
3. **Language mode:** Keep Vietnamese as primary; English terms handled as vocabulary
4. **Don't promise true code-switching:** Set expectations appropriately

**Whisper Behavior:**
- Whisper multilingual is trained on code-switched speech
- Vietnamese -> Whisper tends to transcribe English words phonetically or romanized
- Prompting with English terms helps but isn't guaranteed
- Larger models (medium, large) handle code-switching better

**Recommended Strategy:**
1. Use Whisper large-v3-turbo for best multilingual performance
2. Include developer vocabulary in prompt
3. Post-process common misrecognitions
4. Document limitations clearly
5. Let users add their own vocabulary for specific terms

### Sources

- [TSPC Vietnamese-English Code-Switching](https://arxiv.org/abs/2509.05983) - Research on code-switching ASR
- [VietMix Corpus](https://arxiv.org/html/2505.24472v1) - Vietnamese-English code-mixing data
- [Whisper Multilingual](https://huggingface.co/openai/whisper-large-v3) - Model capabilities
- [WhisperKit Language Detection](https://github.com/argmaxinc/WhisperKit) - Auto-detect features

---

## Feature Dependencies

```
[Custom Vocabulary]
    |
    +---> [Vocabulary UI in Settings]
    |         |
    |         +---> [Word list storage (UserDefaults/JSON)]
    |
    +---> [Prompt construction for WhisperKit]
    |         |
    |         +---> [Token limit handling (224 tokens)]
    |
    +---> [Post-processing replacement]
              |
              +---> [Text insertion service]

[Auto-Translate]
    |
    +---> [WhisperKit translate task]
    |         |
    |         +---> [Verify API support]
    |
    +---> [Toggle UI (settings + menu bar)]
    |
    +---> [History display (original + translation)]

[Auto-Segmentation]
    |
    +---> [VAD integration]
    |         |
    |         +---> [WhisperKit VAD or Silero VAD]
    |
    +---> [Silence threshold logic]
    |         |
    |         +---> [Timer + state machine]
    |
    +---> [Segment finalization flow]
    |         |
    |         +---> [Transcription queue]
    |         |
    |         +---> [Text insertion]
    |
    +---> [Toggle mode enhancement]

[Better English Detection]
    |
    +---> [Developer vocabulary preset]
    |         |
    |         +---> [Custom Vocabulary feature]
    |
    +---> [Prompt engineering]
    |         |
    |         +---> [Custom Vocabulary feature]
    |
    +---> [Post-processing rules]
              |
              +---> [Custom Vocabulary feature]
```

### Dependency Analysis

| Feature | Depends On | Can Be Built Independently |
|---------|-----------|---------------------------|
| Custom Vocabulary | Nothing | YES - Foundation feature |
| Auto-Translate | WhisperKit translate task support | YES - Verify first |
| Auto-Segmentation | VAD implementation | YES - New subsystem |
| Better English Detection | Custom Vocabulary | NO - Build vocabulary first |

**Recommended Build Order:**
1. **Custom Vocabulary** - Foundation for other features
2. **Better English Detection** - Uses vocabulary, high value for target users
3. **Auto-Translate** - Independent, verify WhisperKit support
4. **Auto-Segmentation** - Most complex, can be deferred if needed

---

## Feature Prioritization for v1.1

| Feature | User Value | Implementation Cost | Risk | Priority |
|---------|------------|---------------------|------|----------|
| Custom Vocabulary | HIGH | LOW-MEDIUM | LOW | P1 |
| Better English Detection | HIGH | LOW | LOW | P1 |
| Auto-Translate | MEDIUM | LOW-MEDIUM | MEDIUM (verify API) | P2 |
| Auto-Segmentation | MEDIUM | HIGH | MEDIUM (UX tuning) | P2 |

**Priority Rationale:**
- **P1 Custom Vocabulary:** Foundation feature, enables other improvements, direct user value
- **P1 Better English Detection:** High value for target audience (developers), builds on vocabulary
- **P2 Auto-Translate:** Nice-to-have, verify WhisperKit support before committing
- **P2 Auto-Segmentation:** Highest complexity, needs UX iteration, can defer to v1.2 if needed

---

## Competitor Feature Matrix

| Feature | Superwhisper | Wispr Flow | MacWhisper | VoiceInk | **VoiceType v1.1** |
|---------|--------------|------------|------------|----------|-------------------|
| Custom Vocabulary | Yes (AI hints + replacements) | Yes | Unknown | Unknown | **Planned** |
| Phonetic Hints | No | Unknown | Unknown | Unknown | **No (post-processing instead)** |
| Translation | Yes (cloud) | Yes (cloud) | Yes | Unknown | **Whisper native (offline)** |
| Auto-Segment | Unknown | Unknown | Unknown | Unknown | **Planned** |
| Code-Switching | Generic | Generic | Generic | Generic | **Developer vocabulary preset** |
| Offline | Yes | No | Yes | Yes | **Yes (core value)** |

**Competitive Positioning for v1.1:**
- **vs Superwhisper:** Similar vocabulary approach; advantage in offline translation
- **vs Wispr Flow:** Advantage in offline operation; similar developer focus
- **vs MacWhisper:** More specialized for Vietnamese + developer workflow
- **Unique:** Offline Vietnamese STT with developer vocabulary and native translation

---

## Sources Summary

### HIGH Confidence (Official Documentation)
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) - Feature support, API
- [OpenAI Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide) - Vocabulary techniques
- [Superwhisper Vocabulary Docs](https://superwhisper.com/docs/get-started/interface-vocabulary) - Two-stage approach
- [Silero VAD GitHub](https://github.com/snakers4/silero-vad) - VAD implementation

### MEDIUM Confidence (Verified WebSearch)
- [Picovoice VAD Guide](https://picovoice.ai/blog/complete-guide-voice-activity-detection-vad/) - VAD concepts
- [Deepgram Endpointing](https://developers.deepgram.com/docs/understanding-end-of-speech-detection) - Silence detection
- [TechCrunch Dictation Apps 2025](https://techcrunch.com/2025/12/30/the-best-ai-powered-dictation-apps-of-2025/) - Market context

### LOW Confidence (Research/Single Source)
- [TSPC Vietnamese-English ASR](https://arxiv.org/abs/2509.05983) - Code-switching research
- [VietMix Corpus](https://arxiv.org/html/2505.24472v1) - Code-mixing data
- [Argmax Custom Vocabulary](https://www.argmaxinc.com/blog/whisperkit) - Enterprise SDK features

---

*Feature research for: VoiceType v1.1 Smart Dictation*
*Researched: 2026-01-18*
