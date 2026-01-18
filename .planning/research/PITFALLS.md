# Pitfalls Research

**Domain:** macOS Vietnamese Speech-to-Text Menu Bar App
**Researched:** 2025-01-17 (v1.0), 2026-01-18 (v1.1)
**Confidence:** HIGH (verified via Apple Developer documentation, GitHub issues, community reports)

---

## v1.1 Pitfalls: Smart Dictation Features

*Added: 2026-01-18*
*Features: Custom vocabulary, auto-translate, auto-segmentation, better English detection*

---

### Translation Pitfalls

#### CRITICAL: Apple Translation API Requires SwiftUI Views

**What goes wrong:** The Translation framework cannot be used directly in services. `TranslationSession` must be obtained via SwiftUI view modifiers (`translationTask`), not instantiated directly.

**Why it happens:** Apple designed the API exclusively for SwiftUI. Confirmed by Apple Engineer: UIKit/AppKit apps must host a SwiftUI View to access Translation.

**Consequences:**
- Cannot call translation from `TranscriptionService.swift` directly
- Session lifetime tied to view lifecycle - disappearing views kill sessions
- Requires architectural workaround

**Prevention:**
- Create a lightweight SwiftUI "bridge" view that hosts the TranslationSession
- Use Combine/async to communicate between service layer and SwiftUI bridge
- Consider `UIHostingController` pattern if needed
- Alternative: keep translation in view layer, not service layer

**Detection:** Build fails or runtime error when attempting to instantiate `TranslationSession` outside SwiftUI context.

**Affects:** Auto-translate Vietnamese to English feature

**Sources:** [Apple Translation API iOS 18](https://medium.com/aviv-product-tech-blog/ios-18-apples-translation-api-ea9a5afc281f), [Apple Developer Forums](https://developer.apple.com/forums/thread/758156)

---

#### HIGH: Short Text Detection Failures

**What goes wrong:** Translation source language detection fails on short transcription results.

**Why it happens:** Apple's Translation API needs at least 20 characters for reliable language detection. Short phrases like "ok" or "di" (Vietnamese for "go") may be misdetected.

**Consequences:**
- Wrong translation direction
- Error returned for "unsupported" language pair
- Inconsistent user experience

**Prevention:**
- Explicitly set source language when translating (`source: .init(identifier: "vi")`)
- Never rely on auto-detection for Vietnamese transcription results
- Buffer multiple short segments before translating

**Detection:** Translation returns errors or wrong language output for short phrases.

**Affects:** Auto-translate feature with short dictations

**Sources:** [Apple Translation Documentation](https://developer.apple.com/documentation/translation/translationsession)

---

#### MEDIUM: Language Download UX Friction

**What goes wrong:** First translation attempt triggers system download prompt, surprising users.

**Why it happens:** Language bundles are downloaded on-demand. Users expect "100% offline" but first use requires internet.

**Consequences:**
- Feature appears broken if user is offline on first use
- UX inconsistency with "offline" branding

**Prevention:**
- Call `TranslationSession.prepareTranslation()` proactively during app setup
- Add "Download Translation Languages" option in Settings
- Check `LanguageAvailability().status(from: .init(identifier: "vi"), to: .init(identifier: "en"))` before enabling feature
- Show clear status indicator for language download state

**Detection:** User enables translation, sees system prompt, gets confused.

**Affects:** Auto-translate feature first-time use

**Sources:** [Swift Translation API Guide](https://www.polpiella.dev/swift-translation-api/)

---

#### MEDIUM: Mixed-Language Input Mishandling

**What goes wrong:** Transcription containing both Vietnamese and English words gets partially translated incorrectly.

**Why it happens:** Translation API identifies the "dominant" language even when mixed. Vietnamese sentence with English technical terms may be translated as if it were English.

**Consequences:**
- "Anh ay lam Claude project" translated as English (gibberish output)
- Technical terms get double-translated or mangled

**Prevention:**
- Do NOT translate when custom vocabulary words are detected
- Consider sentence-level language detection before translation
- Provide user toggle: "Translate even if English detected"

**Detection:** Translation output contains nonsense or source text echoed back.

**Affects:** Interaction between vocabulary and translation features

**Sources:** [Apple Developer Documentation](https://developer.apple.com/documentation/translation/)

---

### Segmentation Pitfalls

#### CRITICAL: VAD False Positives in Noisy Environments

**What goes wrong:** Background noise triggers speech detection, causing premature segmentation.

**Why it happens:** Energy-based VAD cannot distinguish speech from noise at low SNR. Air conditioning, keyboard clicks, or distant conversations register as "speech."

**Consequences:**
- Text inserted mid-sentence
- Fragmented, unusable transcriptions
- User frustration with toggle mode

**Prevention:**
- Use hangover schemes (keep speech flag active for extra frames after silence detected)
- Implement hysteresis (different thresholds for speech-start vs speech-end)
- Require minimum speech duration before segment commit (e.g., 500ms)
- Consider Silero VAD over energy-based detection for better accuracy

**Detection:** Segments being committed during obvious pauses, or immediately after starting.

**Affects:** Enhanced toggle mode with auto-segment

**Sources:** [VAD Complete Guide 2025](https://picovoice.ai/blog/complete-guide-voice-activity-detection-vad/), [VAD Best Practices](https://deepgram.com/learn/voice-activity-detection)

---

#### HIGH: Aggressive Segmentation Cuts Off Thinking Pauses

**What goes wrong:** Natural pauses while thinking trigger segmentation, splitting sentences.

**Why it happens:** Whisper's default segmentation uses silence timeouts that don't account for cognitive pauses. Developers dictating complex thoughts pause frequently.

**Consequences:**
- "I want to build a... [segment]... React component" becomes two unrelated segments
- Context lost between segments

**Prevention:**
- Use longer silence thresholds (1.5-2 seconds instead of 0.5 seconds)
- Implement "semantic" pause detection - shorter pauses mid-sentence, longer for sentence boundaries
- Add configurable "pause sensitivity" in Settings
- Consider trailing punctuation hints (no period = likely incomplete)

**Detection:** User feedback about fragmented output, or logs showing frequent short segments.

**Affects:** Enhanced toggle mode with auto-segment

**Sources:** [Aalto Speech Processing - VAD](https://speechprocessingbook.aalto.fi/Recognition/Voice_activity_detection.html)

---

#### MEDIUM: Segment Boundary Audio Artifacts

**What goes wrong:** Cutting audio at segment boundaries clips word beginnings/endings.

**Why it happens:** VAD detects silence AFTER it begins, so cutting at detection point removes the trailing audio of the last word.

**Consequences:**
- Last word of each segment sounds clipped
- Whisper misrecognizes clipped words

**Prevention:**
- Add buffer time (300-500ms) before and after detected speech segments
- Use "prefix padding" and "suffix padding" parameters
- Smooth segment boundaries rather than hard cuts

**Detection:** Transcription shows wrong words at segment boundaries.

**Affects:** Enhanced toggle mode with auto-segment

**Sources:** [OpenAI Realtime VAD](https://platform.openai.com/docs/guides/realtime-vad)

---

#### MEDIUM: Memory Growth with Long Toggle Sessions

**What goes wrong:** Extended toggle-mode sessions accumulate audio buffers, exhausting memory.

**Why it happens:** Audio samples stored in memory while waiting for segment completion. On 8GB Macs, this competes with Whisper model memory.

**Consequences:**
- App slowdown after extended use
- Potential crash on memory pressure
- Model eviction from memory (reload delay)

**Prevention:**
- Set maximum segment duration (e.g., 30 seconds auto-commit)
- Release audio buffers immediately after transcription
- Monitor memory pressure and warn user
- Consider disk-backed buffer for very long sessions

**Detection:** Memory profiler shows growth over time, or app becomes sluggish after 5+ minutes of toggle mode.

**Affects:** Enhanced toggle mode, especially long dictation sessions

**Sources:** [Whisper Memory on 8GB Mac](https://privatewhisper.app/how-to-run-whisper-large-on-mac-easy-2025-guide/)

---

### Vocabulary Pitfalls

#### CRITICAL: Whisper Prompt Token Limit (224 tokens)

**What goes wrong:** Custom vocabulary prompt exceeds token limit, gets truncated.

**Why it happens:** Whisper's context is 448 tokens total (input + output), with official implementation constraining input to 224 tokens. A long word list gets cut off.

**Consequences:**
- Only first ~50-100 words from vocabulary list actually influence transcription
- Users add more words expecting improvement, get none

**Prevention:**
- Limit vocabulary list size (50-75 words maximum)
- Prioritize most frequently mis-transcribed words
- Consider phonetic clustering (group similar-sounding words)
- Document the limitation clearly in UI

**Detection:** Words added to vocabulary still mis-transcribed.

**Affects:** Custom vocabulary with phonetic hints

**Sources:** [Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide), [Prompt Engineering in Whisper](https://medium.com/axinc-ai/prompt-engineering-in-whisper-6bb18003562d)

---

#### HIGH: Initial Prompt Only Affects First 30 Seconds

**What goes wrong:** Custom vocabulary only helps at the beginning of recordings.

**Why it happens:** Whisper's `initial_prompt` is overwritten by the decoding result of each segment. After the first 30-second window, the prompt becomes the previous transcription.

**Consequences:**
- Long recordings lose vocabulary benefit after first segment
- Inconsistent transcription quality within same session

**Prevention:**
- Use `carry_initial_prompt: true` (if supported by WhisperKit)
- For toggle mode: vocabulary resets naturally between segments (actually beneficial)
- For hold-to-talk: less of an issue since recordings are typically <30 seconds

**Detection:** Same word transcribed correctly in first 30 seconds but wrong later.

**Affects:** Custom vocabulary with longer recordings

**Sources:** [Whisper initial_prompt Discussion](https://github.com/openai/whisper/discussions/1189)

---

#### HIGH: WhisperKit promptTokens Bug

**What goes wrong:** Using `promptTokens` in WhisperKit DecodingOptions returns empty transcription.

**Why it happens:** Known bug (Issue #372, October 2025) where filtering tokens and passing via DecodingOptions causes empty output.

**Consequences:**
- Custom vocabulary feature completely broken
- No transcription returned at all

**Prevention:**
- Verify current WhisperKit version has fix before implementing
- Have fallback to transcription without prompts if prompts fail
- Test thoroughly with various prompt token combinations
- Monitor WhisperKit releases for fix

**Detection:** Transcription returns empty string when promptTokens is set, works without.

**Affects:** Custom vocabulary implementation in WhisperKit

**Sources:** [WhisperKit Issue #372](https://github.com/argmaxinc/WhisperKit/issues/372)

---

#### MEDIUM: Regex Replacement Over-Matching

**What goes wrong:** Post-processing replacement rules match unintended text.

**Why it happens:** Simple string replacement (e.g., "ai" -> "AI") matches within words ("chai" -> "chAI").

**Consequences:**
- Correct words get corrupted
- User trust in transcription damaged

**Prevention:**
- Use word-boundary regex (`\bai\b` not `ai`)
- Apply replacements case-sensitively
- Order replacements from most specific to least specific
- Test replacement rules against corpus of common text

**Detection:** Output contains mangled words, especially common Vietnamese words.

**Affects:** Custom vocabulary post-processing

**Sources:** [Find and Replace Best Practices](https://www.baeldung.com/java-remove-accents-from-text)

---

#### MEDIUM: Phonetic Hint Ambiguity

**What goes wrong:** Phonetic hints match multiple possible outputs.

**Why it happens:** Vietnamese phonetics can map to multiple spellings. "iu-ai" could be intended as "UI" but also sounds like "yeu ai" (love who).

**Consequences:**
- Wrong replacement applied
- Context-dependent meaning lost

**Prevention:**
- Require exact phonetic match (stricter matching)
- Consider surrounding context in replacement decisions
- Allow user to confirm/reject replacements for ambiguous cases
- Prioritize technical terms over common words

**Detection:** Common words being replaced with technical terms incorrectly.

**Affects:** Custom vocabulary phonetic matching

---

#### LOW: Vietnamese Diacritic Normalization Issues

**What goes wrong:** Unicode normalization causes rendering or matching issues with Vietnamese text.

**Why it happens:** Vietnamese characters can be represented as composed or decomposed Unicode. Different representations don't match in string comparison.

**Consequences:**
- Replacement rules fail to match
- Display issues in some contexts

**Prevention:**
- Normalize all text to NFC (composed) form before processing
- Handle the special case of "d" (no decomposition for d with stroke)
- Test with various input methods (Telex, VNI, VIQR)

**Detection:** Identical-looking text fails to match in replacement rules.

**Affects:** Custom vocabulary text matching

**Sources:** [Vietnamese Unicode FAQ](https://vietunicode.sourceforge.net/)

---

### English Detection Pitfalls

#### CRITICAL: Whisper Not Designed for Code-Switching

**What goes wrong:** Whisper transcribes mixed Vietnamese/English speech inconsistently or incorrectly.

**Why it happens:** Whisper is "intended for monolingual audio inputs." When languages switch mid-sentence, it may transcribe all in one language or produce garbled output.

**Consequences:**
- "Toi can build mot Claude app" transcribed as pure Vietnamese (wrong) or pure English (wrong)
- English technical terms get Vietnamese phonetic spelling ("klod" instead of "Claude")

**Prevention:**
- Accept this is a fundamental limitation
- Use post-processing vocabulary replacement as primary mitigation
- Consider user-selectable "code-switch tolerance" levels
- For critical English terms, train users to pause slightly around them

**Detection:** English words consistently mis-transcribed in Vietnamese context.

**Affects:** Better English detection in Vietnamese speech

**Sources:** [Whisper Language Discussion](https://github.com/openai/whisper/discussions/1456), [Adapting Whisper for Code-Switching](https://arxiv.org/abs/2412.16507)

---

#### HIGH: Language Detection Flipping Mid-Recording

**What goes wrong:** Auto-detect mode switches detected language mid-transcription based on recent audio.

**Why it happens:** Whisper's language detection runs on each segment. A segment with more English words may flip the entire output to English.

**Consequences:**
- First part of transcription in Vietnamese, suddenly switches to English
- Vietnamese words transliterated as English

**Prevention:**
- Lock language after first detection (don't re-detect per segment)
- Use explicit Vietnamese mode for Vietnamese users
- Implement "dominant language" detection on full audio before transcription
- Show detected language to user for confirmation

**Detection:** Transcription output changes language mid-text.

**Affects:** Auto language mode, better English detection

**Sources:** [Whisper Language Detection Issues](https://github.com/openai/whisper/discussions/529)

---

#### MEDIUM: Short English Segments Misdetected

**What goes wrong:** Brief English phrases in Vietnamese speech are transcribed as Vietnamese.

**Why it happens:** Whisper needs context to detect language. A 2-second "check the API" amid Vietnamese gets absorbed into Vietnamese phonetics.

**Consequences:**
- Technical terms rendered as Vietnamese phonetic gibberish

**Prevention:**
- Build vocabulary list of common English technical terms
- Apply post-processing replacement after transcription
- Consider acoustic features to detect likely English segments (broader phoneme range)

**Detection:** Common English words appear as Vietnamese syllables in output.

**Affects:** Better English detection for technical terms

---

#### MEDIUM: Prompt Can Hallucinate into Transcript

**What goes wrong:** Vocabulary hint words appear in transcript even when not spoken.

**Why it happens:** Whisper may interpret prompt as "expected" content and include it when uncertain. Reported: "80% of the time...I get fully hallucinated output...repeating the same thing."

**Consequences:**
- False technical terms inserted into transcription
- User loses trust in output accuracy

**Prevention:**
- Keep vocabulary prompts minimal
- Prefer long prompts (more stable) over short lists
- Test prompts against silent audio to verify no hallucination
- Consider confidence threshold - reject low-confidence transcriptions

**Detection:** Output contains vocabulary words that weren't spoken.

**Affects:** Interaction between vocabulary and transcription

**Sources:** [Whisper Prompt Discussion](https://github.com/openai/whisper/discussions/1150)

---

### v1.1 Phase-Specific Warnings

| Phase/Feature | Highest Risk Pitfall | Mitigation Priority |
|---------------|---------------------|---------------------|
| Translation | SwiftUI-only API | P0 - Architectural decision required |
| Segmentation | VAD false positives | P0 - Core UX impact |
| Vocabulary | promptTokens bug | P0 - Verify fix before implementing |
| Vocabulary | 224 token limit | P1 - Design vocabulary size limits |
| English Detection | Code-switching unsupported | P1 - Set expectations, use post-processing |
| Translation | Language download UX | P2 - Proactive download in Settings |
| Segmentation | Thinking pause cuts | P2 - Configurable thresholds |

---

### v1.1 Memory Considerations for 8GB Macs

Current v1.0 uses Whisper small model (~250MB in memory). Adding features increases memory pressure:

| Feature | Memory Impact | Mitigation |
|---------|---------------|------------|
| Translation models | Minimal (Apple handles) | Use system Translation API |
| VAD model (Silero) | +1.8MB | Acceptable |
| Longer audio buffers | +1MB per 30s | Auto-commit segments |
| Vocabulary processing | Negligible | In-memory post-processing |

**Recommendation:** Stick with Apple's Translation API (system-managed memory) rather than bringing in additional ML models. Keep Whisper model at "small" for 8GB users; add memory warning if user selects larger models.

---

## v1.0 Pitfalls (Original)

*From: 2025-01-17*

---

## Critical Pitfalls

### Pitfall 1: Accessibility Permission Never Granted in Sandboxed Apps

**What goes wrong:**
With App Sandbox enabled, the Accessibility permission prompt never appears. The app cannot be manually added in System Settings > Privacy & Security > Accessibility. `AXIsProcessTrusted()` always returns false. Text insertion features completely fail.

**Why it happens:**
Accessibility permission falls under macOS TCC (Transparency, Consent, Control) framework. Sandboxed apps cannot request accessibility permissions — Apple explicitly blocks this. The API `AXIsProcessTrustedWithOptions` with prompt enabled is not allowed in sandboxed apps.

**How to avoid:**
1. **Distribute outside Mac App Store** — Use Developer ID signing instead of App Store distribution. This allows non-sandboxed apps.
2. **Use CGEventTap instead of NSEvent** — For global hotkey monitoring, CGEventTap requires Input Monitoring privilege (available to sandboxed apps), while NSEvent global monitors require Accessibility privilege (blocked for sandboxed apps).
3. **Plan for permissions UX** — Create an onboarding flow that guides users through granting Accessibility permission manually.

**Warning signs:**
- `AXIsProcessTrusted()` returns false even after user "grants" permission
- Text insertion works in development but fails in release builds
- App works when run from Xcode but not when exported

**Phase to address:**
Phase 1 (Foundation) — Architecture decision: non-sandboxed + Developer ID distribution from day one.

---

### Pitfall 2: Vietnamese Tone/Diacritic Accuracy with Generic Whisper

**What goes wrong:**
Standard Whisper models produce poor Vietnamese transcription — missing diacritics, wrong tones, incorrect word segmentation. Vietnamese relies on 6 tones and 91 characters with diacritics. Generic multilingual models struggle with regional Vietnamese accents.

**Why it happens:**
OpenAI Whisper was trained primarily on English data. Vietnamese is underrepresented. Regional variations in pronunciation (Northern/Central/Southern Vietnamese) add complexity. Without fine-tuning, the model frequently produces gibberish or strips diacritics.

**How to avoid:**
1. **Use PhoWhisper** — VinAI Research's Whisper variant fine-tuned on 844 hours of diverse Vietnamese accents. State-of-the-art performance on Vietnamese benchmarks.
2. **Test with regional accents early** — Don't assume Northern Vietnamese works for all users.
3. **Provide model selection** — Let users choose between speed (smaller model) and accuracy (larger model).

**Warning signs:**
- Transcription output has no diacritics (e.g., "tieng viet" instead of "tieng Viet")
- Words run together without proper segmentation
- Tone-dependent words are consistently wrong (e.g., "ma" vs "ma" vs "ma")

**Phase to address:**
Phase 1 (Foundation) — Model selection and validation. Use PhoWhisper from the start, not generic Whisper.

---

### Pitfall 3: Text Insertion Blocked by Target App Security

**What goes wrong:**
Text insertion works in some apps but fails silently in others. Password fields, secure text inputs, and some Electron apps reject programmatic text insertion. Users blame your app when the target app is blocking input.

**Why it happens:**
macOS security prevents programmatic text insertion into secure fields. Some apps (banking, password managers) explicitly block accessibility-based input. Electron apps have known bugs with accessibility text selection/insertion.

**How to avoid:**
1. **Implement multiple insertion strategies:**
   - Primary: Accessibility API (`AXUIElement` setValue)
   - Fallback: Clipboard + synthetic Cmd+V keystroke
   - Last resort: Character-by-character keystroke simulation
2. **Detect and warn** — Check if target element is a secure field before attempting insertion
3. **Document limitations** — Be explicit about which apps may not work

**Warning signs:**
- Insertion works in TextEdit but fails in Slack/Discord
- Users report "nothing happens" in specific apps
- Works on first try, fails on subsequent attempts

**Phase to address:**
Phase 2 (Core Features) — Implement robust text insertion with fallback strategies during hotkey+insertion phase.

---

### Pitfall 4: Whisper Model Memory Exhaustion on 8GB Macs

**What goes wrong:**
App loads Whisper medium/large model, consuming 2-4GB RAM. Combined with other apps, Mac runs out of memory. System becomes sluggish, app crashes, or transcription fails silently.

**Why it happens:**
Whisper models have significant memory footprints:
- Tiny: ~75MB
- Base: ~140MB
- Small: ~500MB
- Medium: ~1.5GB
- Large: ~3GB

8GB Macs (common in base M1 MacBook Air) struggle with medium+ models when running alongside browsers and IDEs.

**How to avoid:**
1. **Detect available memory** — Query system memory and recommend appropriate model size
2. **Default to small model** — Accuracy difference between small and medium is modest; speed improvement is significant
3. **Lazy load models** — Don't load model at app launch; load when user first triggers recording
4. **Unload when idle** — Release model memory after period of inactivity

**Warning signs:**
- App works in development (16GB+ Mac) but crashes on user machines
- "Memory pressure" warnings in Activity Monitor during transcription
- Transcription times become inconsistent

**Phase to address:**
Phase 1 (Foundation) — Model loading strategy. Phase 3 (Polish) — Memory management optimization.

---

### Pitfall 5: Audio Buffer Underrun During Recording

**What goes wrong:**
Recording starts but audio is choppy, words are missing, or recording stops unexpectedly. Built-in Mac microphone has inherent 40ms+ latency. Under CPU load, audio buffer underruns cause dropouts.

**Why it happens:**
- Default buffer size too small for system load
- Whisper inference running on same thread as audio capture
- Built-in Mac microphones have known latency issues on Apple Silicon
- USB microphones may have driver issues on M1/M2

**How to avoid:**
1. **Use appropriate buffer size** — 256-512 samples at 44.1kHz/48kHz is safe starting point
2. **Separate audio capture from processing** — Capture audio on dedicated thread, process in background
3. **Convert audio format before Whisper** — Whisper requires 16kHz WAV; do conversion asynchronously
4. **Test with built-in mic and USB mics** — Both have different failure modes

**Warning signs:**
- Words missing from middle of sentences
- Audio sounds "robotic" or stuttered
- Recording works for short phrases but fails for long dictation

**Phase to address:**
Phase 2 (Core Features) — Audio capture implementation with proper threading model.

---

### Pitfall 6: Global Hotkey Conflicts with Other Apps

**What goes wrong:**
Your chosen hotkey (e.g., Cmd+Shift+Space) is already used by Spotlight, Alfred, Raycast, or another app. User enables your hotkey but it never triggers, or worse, triggers something else entirely.

**Why it happens:**
macOS has no central hotkey registry. Multiple apps can register the same global hotkey. The "winner" depends on registration order. Popular hotkey combinations are almost always taken.

**How to avoid:**
1. **Detect conflicts** — Check if hotkey is already registered before claiming it
2. **Choose unusual defaults** — Avoid common combos (Cmd+Space, Cmd+Shift+Space). Consider Ctrl+Option+Space or F-key based shortcuts.
3. **Provide clear feedback** — If hotkey registration fails, tell user why and suggest alternatives
4. **Support hold-to-talk** — Physical key holding is less likely to conflict than single shortcuts

**Warning signs:**
- Hotkey works during development but not on user machines
- Users report "hotkey does nothing"
- Hotkey works after disabling other apps

**Phase to address:**
Phase 2 (Core Features) — Hotkey registration with conflict detection.

---

### Pitfall 7: Notarization Failures Block Distribution

**What goes wrong:**
App works perfectly in development. You sign it with Developer ID, submit for notarization, and it fails or gets stuck "In Progress" indefinitely. Users who download the app see "cannot be verified" warnings.

**Why it happens:**
- Hardened Runtime not enabled
- Embedded binaries (whisper.cpp) not properly signed
- Missing entitlements for required capabilities
- Notarization service occasionally has delays (21+ hours reported)
- Certificate issues or revocation

**How to avoid:**
1. **Enable Hardened Runtime from day one** — Don't add it later
2. **Sign all embedded binaries** — whisper.cpp dylib must be signed with your Developer ID
3. **Use xcrun notarytool** — Not the deprecated altool
4. **Staple the ticket** — Use `xcrun stapler` after notarization succeeds
5. **Test full distribution flow early** — Don't wait until launch to test notarization

**Warning signs:**
- App runs from Xcode but not from DMG
- Users must right-click > Open to bypass Gatekeeper
- Notarization log shows "hardened runtime not enabled"

**Phase to address:**
Phase 1 (Foundation) — Set up signing and notarization workflow. Test before writing significant code.

---

### Pitfall 8: SwiftUI MenuBarExtra Settings Window Failure

**What goes wrong:**
`SettingsLink` doesn't work in `MenuBarExtra`. Settings window appears behind other windows, doesn't get focus, or never opens at all. Users can't configure the app.

**Why it happens:**
SwiftUI's `SettingsLink` assumes your app is "active" in the traditional sense. Menu bar apps use `NSApplication.ActivationPolicy.accessory` — they're not in the app switcher, not "active" in the normal sense. SwiftUI doesn't handle this edge case well.

**How to avoid:**
1. **Use hidden window workaround** — Declare a hidden window before Settings scene
2. **Manually activate app** — Call `NSApp.activate(ignoringOtherApps: true)` before opening Settings
3. **Use AppKit for Settings** — Fall back to `NSWindowController` for settings if SwiftUI fails
4. **Scene declaration order matters** — Hidden window must come before Settings scene

**Warning signs:**
- Settings menu item does nothing
- Settings window opens but is behind other windows
- Works in Xcode, fails in release

**Phase to address:**
Phase 3 (Polish) — Settings window implementation with proper activation handling.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding hotkey | Faster initial development | No user customization, conflict with other apps | Never — conflicts are too common |
| Synchronous model loading | Simpler code | UI freezes on app launch, poor UX | Never — always load async |
| Single text insertion method | Less code to maintain | Fails silently in many apps | Never — need fallback strategies |
| Clipboard-only insertion | Works everywhere | Overwrites user's clipboard, annoying | Only as fallback, restore clipboard after |
| Bundling large model by default | Works out of box | Huge app size (3GB+), slow downloads | MVP only — add model download later |
| Ignoring regional Vietnamese | "Works for me" | Poor accuracy for Southern/Central speakers | MVP only — expand testing post-launch |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| whisper.cpp | Using Python whisper instead | Use whisper.cpp with CoreML for Apple Silicon optimization |
| CoreML acceleration | Forgetting first-run compilation delay | Warn users first inference is slow while ANE compiles model |
| Audio capture | Wrong sample rate (Whisper needs 16kHz) | Capture at system rate, convert to 16kHz before inference |
| Accessibility API | Assuming permission once granted | Check `AXIsProcessTrusted()` on each operation — user can revoke |
| Global hotkeys | Using NSEvent globalMonitor | Use CGEventTap for Input Monitoring (sandboxed-compatible) |
| Text insertion | Direct character insertion | Use Accessibility setValue with clipboard+paste fallback |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Model loaded at launch | 3-5 second app startup delay | Lazy load on first use | Immediately noticeable |
| Synchronous transcription | UI freezes during processing | Run inference on background thread | Any recording > 5 seconds |
| No model unloading | Memory usage grows indefinitely | Unload after 5 min idle | After ~1 hour of use |
| Audio capture on main thread | Choppy recordings, UI lag | Dedicated audio thread | Under any CPU load |
| Large model on 8GB Mac | System-wide slowdown, crashes | Default to small model, detect memory | First transcription attempt |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Requesting unnecessary entitlements | App rejection, security flags | Request only what's needed (Accessibility, Microphone) |
| Storing audio recordings | Privacy violation, data breach | Process in memory only, never persist audio |
| Not clearing transcription buffer | Previous text visible to other apps | Clear buffer after insertion |
| Skipping notarization for testing | "Works on my machine" syndrome | Notarize even test builds |
| Embedding API keys | Keys extracted from binary | N/A — this is offline-only, no keys needed |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No recording indicator | Users don't know mic is active | Floating indicator + menu bar icon change |
| Silent failures | Users think app is broken | Toast/notification on any error |
| Overwriting clipboard | Lose important copied content | Save clipboard, insert text, optionally restore |
| No way to cancel | Stuck in recording mode | ESC key always cancels, timeout after 30s |
| Settings window doesn't appear | Can't configure app | Multiple activation attempts, manual workaround guidance |
| Model download with no progress | Appears frozen | Progress indicator, size estimate, cancel option |

---

## "Looks Done But Isn't" Checklist

- [ ] **Text insertion:** Works in TextEdit but verify in VSCode, Terminal, Slack, Notion, Chrome — each has different accessibility behavior
- [ ] **Vietnamese accuracy:** Test with Northern AND Southern accents — regional differences are significant
- [ ] **Permission flow:** Test fresh install experience — user must grant both Microphone and Accessibility
- [ ] **8GB Mac:** Test on base model MacBook Air — memory constraints reveal issues
- [ ] **Long recordings:** Test 2+ minute dictation — buffer management issues emerge
- [ ] **App quit/relaunch:** Test hotkey still works after app restart without manual re-grant
- [ ] **Notarized build:** Test DMG download from Safari — quarantine attribute triggers Gatekeeper
- [ ] **First CoreML run:** First transcription is slow (ANE compilation) — subsequent runs faster
- [ ] **USB microphone:** Test with external mic — different latency profile than built-in
- [ ] **Hold-to-talk vs toggle:** Both modes need separate testing — different state machine

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Sandboxed architecture | HIGH | Rewrite for non-sandboxed, change distribution model |
| Wrong Whisper model | MEDIUM | Replace model, re-test accuracy, update download |
| Text insertion failures | MEDIUM | Add fallback strategies, may need to re-architect |
| Memory issues | MEDIUM | Add lazy loading, model unloading, memory detection |
| Hotkey conflicts | LOW | Add conflict detection, suggest alternatives |
| Notarization failures | LOW | Enable hardened runtime, re-sign binaries |
| SwiftUI Settings issues | LOW | Add AppKit workaround, scene reordering |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Accessibility in sandbox | Phase 1: Architecture | `AXIsProcessTrusted()` returns true in release build |
| Vietnamese accuracy | Phase 1: Model selection | >95% accuracy on test sentences with diacritics |
| Text insertion failures | Phase 2: Core features | Text appears in 5+ different target apps |
| Memory exhaustion | Phase 1 + 3: Model loading + optimization | Works on 8GB Mac with browser open |
| Audio buffer issues | Phase 2: Audio capture | No dropouts in 2-minute recording |
| Hotkey conflicts | Phase 2: Hotkey system | Conflict detection warns user |
| Notarization | Phase 1: Build setup | Downloaded DMG runs without Gatekeeper bypass |
| Settings window | Phase 3: Polish | Settings opens and focuses reliably |

---

## Sources

**v1.1 Sources (HIGH confidence):**
- [Apple TranslationSession Documentation](https://developer.apple.com/documentation/translation/translationsession)
- [WhisperKit GitHub Issues](https://github.com/argmaxinc/WhisperKit/issues/372)
- [OpenAI Whisper Prompting Guide](https://cookbook.openai.com/examples/whisper_prompting_guide)

**v1.1 Sources (MEDIUM confidence):**
- [Picovoice VAD Guide 2025](https://picovoice.ai/blog/complete-guide-voice-activity-detection-vad/)
- [Whisper Code-Switching Research](https://arxiv.org/abs/2412.16507)
- [Apple Translation API Medium Article](https://medium.com/aviv-product-tech-blog/ios-18-apples-translation-api-ea9a5afc281f)

**v1.0 Sources:**
- [Apple Developer Documentation - Resolving Common Notarization Issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)
- [Apple Developer Forums - Accessibility Permission in Sandboxed Apps](https://developer.apple.com/forums/thread/707680)
- [whisper.cpp GitHub - macOS Integration Issues](https://github.com/ggml-org/whisper.cpp)
- [VinAI Research - PhoWhisper for Vietnamese ASR](https://github.com/VinAIResearch/PhoWhisper)
- [Peter Steinberger - Showing Settings from macOS Menu Bar Items](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
- [Apple Developer Forums - CGEventTap vs NSEvent for Global Hotkeys](https://developer.apple.com/forums/thread/678819)
- [Voicci - Whisper Performance on Apple Silicon](https://www.voicci.com/blog/apple-silicon-whisper-performance.html)
- [ClipBook - Text Insertion via Accessibility](https://clipbook.app/blog/paste-to-other-applications/)
- [Apple Developer - Developer ID Signing](https://developer.apple.com/developer-id/)

---
*Pitfalls research for: VoiceType - macOS Vietnamese Speech-to-Text*
*v1.0 Researched: 2025-01-17*
*v1.1 Researched: 2026-01-18*
