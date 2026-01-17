# Pitfalls Research

**Domain:** macOS Vietnamese Speech-to-Text Menu Bar App
**Researched:** 2025-01-17
**Confidence:** HIGH (verified via Apple Developer documentation, GitHub issues, community reports)

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
*Researched: 2025-01-17*
