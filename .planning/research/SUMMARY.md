# Project Research Summary

**Project:** VoiceType - macOS Vietnamese Speech-to-Text
**Domain:** Native macOS Menu Bar Application with ML Inference
**Researched:** 2026-01-17
**Confidence:** HIGH

## Executive Summary

VoiceType is a native macOS menu bar application for Vietnamese speech-to-text dictation. The research reveals this is a well-understood problem domain with mature tooling: **whisper.cpp** provides proven ML inference on Apple Silicon, **PhoWhisper** (VinAI's Vietnamese-fine-tuned Whisper) achieves state-of-the-art accuracy (4.97% WER vs ~15-20% for generic Whisper), and macOS provides all necessary system APIs for audio capture, global hotkeys, and text insertion. The recommended approach is a hybrid SwiftUI/AppKit architecture distributed outside the Mac App Store with Developer ID signing.

The critical architectural decision is **non-sandboxed distribution**. Text insertion via Accessibility API and global hotkeys via CGEventTap are both blocked in sandboxed apps. This must be decided in Phase 1 — retrofitting later is expensive. The secondary critical decision is using **PhoWhisper** from day one rather than generic Whisper. Vietnamese transcription quality is the core value proposition; using the wrong model undermines the entire product.

Key risks center on macOS permissions (Accessibility, Input Monitoring, Microphone) which require user interaction and cannot be programmatically granted, memory management on 8GB Macs with larger models, and text insertion reliability across diverse target applications. All risks have known mitigations documented in the pitfalls research.

## Key Findings

### Recommended Stack

The stack is native macOS with ML inference via whisper.cpp. Swift/SwiftUI handles UI and state management while AppKit provides system integration. This hybrid approach is necessary — pure SwiftUI cannot handle global hotkeys, floating panels, or accessibility APIs.

**Core technologies:**
- **Swift 5.9+ / SwiftUI**: Primary language and UI framework — native macOS development with modern declarative UI
- **whisper.cpp + SwiftWhisper**: ML inference engine — 3-8x faster than Python Whisper on Apple Silicon with CoreML/Metal
- **PhoWhisper-medium (GGML format)**: Vietnamese ASR model — 4.97% WER on VIVOS benchmark, fine-tuned on 844h diverse Vietnamese accents
- **AVAudioEngine**: Audio capture — native macOS microphone access with real-time streaming
- **CGEventTap**: Global hotkeys — system-wide keyboard capture for push-to-talk
- **AXUIElement**: Text insertion — accessibility API for inserting text at cursor position

**Key version requirements:**
- macOS 14+ (for MenuBarExtra, latest SwiftUI features)
- Xcode 15+ (Swift 5.9)
- SwiftWhisper 1.2.0+ (latest GGML format)

### Expected Features

**Must have (table stakes):**
- Hold-to-talk activation — primary input mode, immediate recording on key hold
- Toggle on/off mode — hands-free option for longer dictation
- Global hotkey (configurable) — works from any app without switching
- Text insertion at cursor — core function via accessibility API
- Visual recording indicator — users must know when mic is active
- Audio feedback on start/stop — confirm recording state without looking
- Offline operation — core value proposition, no internet dependency
- Basic settings persistence — preferences saved between sessions

**Should have (differentiators):**
- PhoWhisper model integration — state-of-art Vietnamese accuracy
- Model selection UI — let users choose speed vs accuracy tradeoff
- Custom vocabulary — technical terms and names for developer workflows
- Transcription history — review and reuse recent transcriptions
- Low resource usage — opportunity vs competitors using 800MB+ RAM

**Defer (v2+):**
- Bilingual Vietnamese-English — complex cross-lingual phoneme recognition
- Local LLM post-processing — only if users bring their own models
- Real-time streaming transcription — distracting in practice, add complexity
- Voice commands for editing — significant NLU complexity, out of scope

### Architecture Approach

The architecture follows a layered pattern: UI Layer (menu bar, floating overlay, settings), Application Core (hotkey manager, recording manager, state manager), Processing Layer (transcription engine), and System Integration (text insertion, clipboard). The key patterns are hybrid SwiftUI/AppKit for system integration, protocol-based engine abstraction for transcription flexibility, and fallback chain for text insertion (accessibility API first, clipboard paste second).

**Major components:**
1. **Menu Bar Controller** — NSStatusItem for status display, NSMenu for quick access
2. **Hotkey Manager** — CGEventTap for global keyboard capture, hold-to-talk state machine
3. **Recording Manager** — AVAudioEngine with input tap, audio buffering to 16kHz PCM
4. **Transcription Engine** — SwiftWhisper wrapper around whisper.cpp with CoreML acceleration
5. **Text Insertion Service** — AXUIElement primary with NSPasteboard+Cmd+V fallback
6. **Settings Panel** — SwiftUI window with hotkey configuration and model selection

### Critical Pitfalls

1. **Sandbox blocks Accessibility permission** — Distribute via Developer ID, not Mac App Store. AXIsProcessTrusted() always returns false in sandboxed apps.

2. **Generic Whisper fails Vietnamese** — Use PhoWhisper from day one. Standard Whisper produces ~15-20% WER vs PhoWhisper's 4.97%. Missing diacritics and wrong tones make output unusable.

3. **Text insertion fails in some apps** — Implement fallback chain: accessibility API first, clipboard paste second, character-by-character keystroke third. Test in VSCode, Terminal, Slack, browsers.

4. **Memory exhaustion on 8GB Macs** — Default to PhoWhisper-small (600MB), lazy load models, unload when idle. Medium model (1.5GB) can crash base MacBook Air.

5. **Notarization blocks distribution** — Enable Hardened Runtime from day one, sign all embedded binaries including whisper.cpp dylib, test notarized build flow early.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation
**Rationale:** Architecture decisions (non-sandboxed, PhoWhisper) must be made first — they affect everything downstream. Permissions and app shell are prerequisites for all features.
**Delivers:** Menu bar app shell, permission handling flow, build/sign/notarize workflow, PhoWhisper model loading
**Addresses:** Settings persistence, offline operation foundation
**Avoids:** Sandbox pitfall, notarization pitfall, wrong-model pitfall

### Phase 2: Audio Pipeline
**Rationale:** Can't transcribe without audio. Audio capture is independent of transcription implementation and can be tested with file output.
**Delivers:** AVAudioEngine recording, 16kHz conversion, buffering, start/stop state machine
**Uses:** AVAudioEngine, AVFoundation frameworks
**Implements:** Recording Manager component
**Avoids:** Audio buffer underrun pitfall

### Phase 3: Transcription Integration
**Rationale:** Once audio capture works, add ML inference. Can test transcription independently before wiring to text insertion.
**Delivers:** SwiftWhisper integration, PhoWhisper model inference, CoreML acceleration
**Uses:** whisper.cpp via SwiftWhisper, PhoWhisper-medium GGML model
**Implements:** Transcription Engine component
**Avoids:** Memory exhaustion pitfall (add lazy loading)

### Phase 4: System Integration
**Rationale:** Global hotkeys and text insertion both require accessibility/input monitoring permissions — group them. This is where hold-to-talk UX comes together.
**Delivers:** Global hotkey capture, hold-to-talk mode, toggle mode, text insertion with fallback, floating recording indicator
**Uses:** CGEventTap, AXUIElement, NSPasteboard, KeyboardShortcuts library
**Implements:** Hotkey Manager, Text Insertion Service, Floating Overlay
**Avoids:** Text insertion failures pitfall, hotkey conflicts pitfall

### Phase 5: Polish
**Rationale:** Once core functionality works end-to-end, add user-facing polish. Settings UI, model selection, and distribution readiness.
**Delivers:** Settings panel, hotkey configuration UI, model selection UI, audio feedback sounds, auto-update (Sparkle)
**Implements:** Settings Panel, final UX polish
**Avoids:** SwiftUI Settings window pitfall (use workarounds)

### Phase Ordering Rationale

- **Foundation before Audio:** Non-sandboxed architecture and signing workflow must be verified before writing feature code. A sandboxed mistake discovered in Phase 4 requires full rewrite.
- **Audio before Transcription:** Audio pipeline can be tested independently (save to file, verify quality). Transcription depends on audio input.
- **Transcription before System Integration:** Can test Vietnamese accuracy manually before adding automated text insertion. Catches model quality issues early.
- **System Integration groups hotkeys + insertion:** Both require similar macOS permissions. Testing them together validates the complete user flow.
- **Polish last:** Settings UI and distribution polish should not block core functionality validation.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Transcription):** CoreML model conversion for PhoWhisper may need debugging — community examples exist but not always well-documented
- **Phase 4 (System Integration):** Text insertion edge cases in specific apps (Electron apps, Terminal) may need app-specific workarounds

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** Menu bar apps are well-documented, many examples exist
- **Phase 2 (Audio Pipeline):** AVAudioEngine usage is thoroughly documented by Apple
- **Phase 5 (Polish):** Settings UI patterns are established, SwiftUI workarounds documented

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official Apple docs, whisper.cpp extensively documented, PhoWhisper has academic paper |
| Features | MEDIUM | Based on competitor analysis and user complaints, not direct user research |
| Architecture | HIGH | Multiple reference implementations (VoiceInk, Superwhisper), Apple documentation |
| Pitfalls | HIGH | Verified via Apple Developer Forums, GitHub issues, developer blog posts |

**Overall confidence:** HIGH

### Gaps to Address

- **Regional Vietnamese accents:** Research confirms PhoWhisper trained on diverse accents, but real-world testing with Northern/Central/Southern speakers needed during Phase 3
- **Text insertion in specific apps:** Electron apps (Slack, Discord, VS Code) may have unique accessibility behaviors — needs empirical testing in Phase 4
- **Memory thresholds:** Exact memory limits for 8GB Macs need measurement — lazy loading strategy may need tuning based on real usage patterns
- **Hotkey conflict detection:** Research shows conflicts are common but exact detection mechanism needs implementation validation

## Sources

### Primary (HIGH confidence)
- [PhoWhisper GitHub](https://github.com/VinAIResearch/PhoWhisper) — Vietnamese ASR benchmarks, model specifications
- [PhoWhisper Paper](https://arxiv.org/abs/2406.02555) — ICLR 2024, WER benchmarks, training data details
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — CoreML support, Apple Silicon performance
- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) — Swift integration patterns
- [Apple Developer: AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement) — Text insertion API
- [Apple Developer: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) — Permission limitations
- [Apple Developer Forums](https://developer.apple.com/forums/) — Accessibility in sandboxed apps, notarization issues

### Secondary (MEDIUM confidence)
- [VoiceInk GitHub](https://github.com/Beingpax/VoiceInk) — Reference implementation for architecture patterns
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global hotkey library
- [Peter Steinberger - Settings from Menu Bar](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — SwiftUI workarounds
- [TechCrunch Dictation Apps 2025](https://techcrunch.com/2025/12/30/the-best-ai-powered-dictation-apps-of-2025/) — Competitor feature analysis

### Tertiary (LOW confidence)
- Competitor pricing and feature claims — may change, needs validation
- Community GGML model conversions — quality varies, test before shipping

---
*Research completed: 2026-01-17*
*Ready for roadmap: yes*
