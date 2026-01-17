# Roadmap: VoiceType

## Overview

VoiceType delivers multilingual speech-to-text dictation for macOS in four phases. We start with a non-sandboxed menu bar shell and Whisper model loading (the architecture decisions that affect everything downstream), then build audio capture and transcription as a combined pipeline, integrate global hotkeys and text insertion for the complete user flow, and finish with settings UI and history features.

**Note:** Using WhisperKit with generic Whisper "small" model (multilingual) instead of PhoWhisper. Supports both Vietnamese and English.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4): Planned milestone work
- Decimal phases (e.g., 2.1): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Foundation** - Menu bar app shell, permissions, Whisper model loading
- [x] **Phase 2: Audio + Transcription** - Recording pipeline and ML inference
- [x] **Phase 3: System Integration** - Global hotkeys, text insertion, hold-to-talk and toggle modes
- [ ] **Phase 4: Polish** - Settings UI, model selection, transcription history

## Phase Details

### Phase 1: Foundation
**Goal**: App runs as menu bar app with correct architecture (non-sandboxed) and can load Whisper model
**Depends on**: Nothing (first phase)
**Requirements**: APP-01, APP-02, APP-03, SET-02, SET-03
**Success Criteria** (what must be TRUE):
  1. App appears in menu bar with status icon (no dock icon)
  2. App requests and handles microphone and accessibility permissions
  3. App can start on login (user-configurable)
  4. Whisper model loads successfully and persists across app launches
  5. Settings menu accessible from menu bar icon
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md - Menu bar app shell with SwiftUI MenuBarExtra and permission handling
- [x] 01-02-PLAN.md - WhisperKit integration, Whisper model loading, login item management

### Phase 2: Audio + Transcription
**Goal**: App can record audio and transcribe Vietnamese speech to text offline
**Depends on**: Phase 1
**Requirements**: REC-01, REC-02, REC-03, REC-04, REC-05, TRS-01, TRS-02, TRS-03, TRS-04, TRS-05
**Success Criteria** (what must be TRUE):
  1. App captures audio from microphone when recording is triggered
  2. Visual indicator shows recording state (menu bar icon change + floating indicator)
  3. Audio feedback plays on recording start and stop
  4. Speech is transcribed to text (Whisper multilingual - supports Vietnamese and English)
  5. Transcription works 100% offline with punctuation and paragraph breaks
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md - Audio capture pipeline (AVAudioEngine, 16kHz conversion)
- [x] 02-02-PLAN.md - Recording state management and visual/audio feedback
- [x] 02-03-PLAN.md - WhisperKit integration with Whisper small model (multilingual)

### Phase 3: System Integration
**Goal**: User can trigger recording with global hotkey and have text inserted at cursor
**Depends on**: Phase 2
**Requirements**: ACT-01, ACT-02, ACT-03, ACT-04, OUT-01, OUT-02, OUT-03
**Success Criteria** (what must be TRUE):
  1. User can hold hotkey to record, release to transcribe (hold-to-talk mode)
  2. User can toggle recording on/off with hotkey (toggle mode)
  3. Global hotkey works from any app
  4. User can configure custom hotkey
  5. Transcribed text is inserted at cursor in any macOS app (with clipboard fallback)
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md - HotkeyService (KeyboardShortcuts, hold-to-talk/toggle) + TextInsertionService (AX + clipboard)
- [x] 03-02-PLAN.md - Integration wiring (hotkey->recording, transcription->insertion) + Settings UI

### Phase 4: Polish
**Goal**: User can configure model size, switch languages, and view transcription history
**Depends on**: Phase 3
**Requirements**: SET-01, HST-01, HST-02, HST-03
**Success Criteria** (what must be TRUE):
  1. User can choose between Whisper model sizes (tiny/base/small/medium/large)
  2. User can switch language mode with hotkey (Auto/Vietnamese/English)
  3. Status feedback shown when blocked (downloading model, transcribing, etc.)
  4. App stores recent transcriptions
  5. User can view and copy text from transcription history
**Plans**: 4 plans

Plans:
- [ ] 04-01-PLAN.md - Language mode selection (Auto/Vietnamese/English) + cycle hotkey (Option+L)
- [ ] 04-02-PLAN.md - Status feedback UI (recording, transcribing, downloading, error states)
- [ ] 04-03-PLAN.md - Model size selection (tiny/base/small/medium/large) with download progress
- [ ] 04-04-PLAN.md - Transcription history storage and viewing with SwiftData

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete | 2026-01-17 |
| 2. Audio + Transcription | 3/3 | Complete | 2026-01-17 |
| 3. System Integration | 2/2 | Complete | 2026-01-17 |
| 4. Polish | 0/4 | Planned | - |

---
*Roadmap created: 2025-01-17*
*Phase 1 planned: 2025-01-17*
*Phase 2 planned: 2026-01-17*
*Phase 3 planned: 2026-01-17*
*Phase 4 planned: 2026-01-18*
*Depth: quick (4 phases, 11 plans)*
