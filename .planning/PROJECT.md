# VoiceType

## What This Is

macOS menu bar app for Vietnamese speech-to-text dictation. Hold a hotkey, speak in Vietnamese (or English), and text appears at your cursor. Runs 100% offline with WhisperKit on Apple Silicon. Designed for developers who want to "vibe code" — dictate prompts to AI or write documentation without typing.

## Core Value

Noi tieng Viet, ra text chinh xac, khong can internet.

## Requirements

### Validated

- ✓ Nhấn hotkey bắt đầu ghi âm, nói tiếng Việt, thả ra có text — v1.0
- ✓ Hỗ trợ 2 mode: hold-to-talk và toggle on/off — v1.0
- ✓ Text được insert vào ô đang focus (bất kỳ app nào) — v1.0
- ✓ Chạy offline với local model (không cần internet) — v1.0
- ✓ Menu bar app với icon trạng thái — v1.0
- ✓ Floating indicator khi đang recording — v1.0
- ✓ Cài đặt hotkey tuỳ chỉnh — v1.0
- ✓ Độ chính xác cao cho tiếng Việt — v1.0 (Whisper multilingual)
- ✓ Model size selection (tiny/base/small/medium/large) — v1.0
- ✓ Transcription history with copy/delete — v1.0
- ✓ Language mode switching (Auto/Vietnamese/English) — v1.0

### Active

**v1.1 — Smart Dictation**

- [ ] Auto-translate to English — toggle trong settings, nói Việt ra text English
- [ ] Enhanced toggle mode với auto-segment — tự insert khi pause, không đợi manual stop

**v1.2 — Custom Vocabulary** (planned)

- [ ] Custom vocabulary với phonetic hints — "iu-ai" → "UI", "cờ-lốt" → "Claude"
- [ ] Better English detection — improve transcription của English words trong Vietnamese speech

### Out of Scope

- Real-time streaming display (từng từ hiện ra khi nói) — deferred to v2, complexity vs value
- Mobile app — macOS only
- Windows/Linux — macOS only
- Cloud-based STT — phải offline
- Voice commands ("xóa câu", "xuống dòng") — deferred, significant NLU complexity

## Context

**Shipped v1.0:** 2026-01-18

**Current state:** 1,827 LOC Swift, macOS 14+, Apple Silicon optimized.

**Tech stack:**
- SwiftUI + MenuBarExtra
- WhisperKit (CoreML Whisper models)
- KeyboardShortcuts (global hotkeys)
- SwiftData (history persistence)
- Accessibility API (text insertion)

**Use case:** Developer dictation — speak Vietnamese to AI chat (Claude, Cursor) or write documentation.

## Constraints

- **Platform**: macOS only (Apple Silicon optimized)
- **Connectivity**: Must work 100% offline
- **Cost**: Free/open-source model only (WhisperKit/Whisper)
- **Language**: Vietnamese speech recognition (primary), English (secondary)
- **Privacy**: Audio never leaves device

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Non-sandboxed distribution | Accessibility API, CGEventTap require it | ✓ Good |
| WhisperKit over SwiftWhisper | CoreML optimization, auto model download, simpler API | ✓ Good |
| Whisper multilingual (not PhoWhisper) | Supports both Vietnamese + English, no hallucination | ✓ Good |
| NSSound over AudioServicesPlaySystemSound | iOS sound IDs don't work on macOS | ✓ Good |
| Pure AppKit FloatingIndicatorPanel | SwiftUI NSHostingView caused constraint crashes | ✓ Good |
| Option+Space default hotkey | Non-conflicting, easy to hold for hold-to-talk | ✓ Good |
| Dual text insertion (AX + clipboard) | Electron apps don't support AX, clipboard fallback works | ✓ Good |
| SwiftData for history | Modern Apple framework, auto-sync with @Query | ✓ Good |
| UserDefaults over @AppStorage | @AppStorage conflicts with @Observable macro | ✓ Good |
| Computed Binding for async pickers | Avoids race condition with UserDefaults | ✓ Good |

---
*Last updated: 2026-01-18 after starting v1.1 milestone*
