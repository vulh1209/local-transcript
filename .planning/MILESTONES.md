# Project Milestones: VoiceType

## v1.0 MVP (Shipped: 2026-01-18)

**Delivered:** macOS menu bar app for Vietnamese speech-to-text dictation, running 100% offline with WhisperKit.

**Phases completed:** 1-4 (12 plans total)

**Key accomplishments:**

- SwiftUI menu bar app with non-sandboxed architecture for macOS 14+ (Apple Silicon optimized)
- WhisperKit integration with 5 model sizes (tiny to large-v3) and automatic download
- Vietnamese speech-to-text transcription running 100% offline with punctuation
- Global hotkey (Option+Space) with hold-to-talk and toggle modes
- Text insertion at cursor via Accessibility API with clipboard fallback
- SwiftData-backed transcription history with copy/delete (100-item limit)

**Stats:**

- 158 files created/modified
- 1,827 lines of Swift
- 4 phases, 12 plans, ~30 tasks
- 1 day from start to ship (2026-01-17 → 2026-01-18)

**Git range:** `feat(01-01)` → `feat(04-05)`

**What's next:** v1.1 with custom vocabulary, developer mode formatting, or auto-translation

---
