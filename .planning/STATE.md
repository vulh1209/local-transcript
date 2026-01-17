# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-17)

**Core value:** Noi tieng Viet, ra text chinh xac, khong can internet.
**Current focus:** Milestone v1 COMPLETE

## Current Position

Phase: 4 of 4 (Polish)
Plan: 4 of 4 in current phase - COMPLETE
Status: Milestone complete
Last activity: 2026-01-18 - Completed 04-03-PLAN.md (Model Size Selection)

Progress: [##########] 100% (10 of 10 total plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 10
- Average duration: 5 min
- Total execution time: 52 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 2/2 | 13 min | 6.5 min |
| 02-audio-transcription | 2/3 | 6 min | 3 min |
| 03-system-integration | 2/2 | 9 min | 4.5 min |
| 04-polish | 4/4 | 24 min | 6 min |

**Recent Trend:**
- Last 5 plans: 04-01 (6 min), 04-02 (6 min), 04-04 (8 min), 04-03 (4 min)
- Trend: Consistent ~4-8 min per plan

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Non-sandboxed distribution (Accessibility API, CGEventTap require it)
- [Roadmap]: Whisper small multilingual (supports Vietnamese + English, ~250MB)
- [Roadmap]: Combined Audio + Transcription phase (natural testing boundary)
- [01-01]: Hidden window scene must be declared before Settings scene for workaround
- [01-01]: macOS 14+ minimum target for openSettings environment
- [01-02]: Lazy model loading - load on first use, not app launch (prevents 3-5s startup freeze)
- [01-02]: Model storage at ~/Library/Application Support/LocalTranscript/
- [01-02]: SMAppService.mainApp for login item (reads from system state, user can change externally)
- [02-01]: Query input format at runtime instead of hardcoding sample rate (AirPods, USB mics differ)
- [02-01]: Convert in tap callback to avoid accumulating raw buffers
- [02-01]: AVAudioConverter callback pattern for variable-length input handling
- [02-02]: System sounds 1113/1114 for begin/end_record - respects user volume settings
- [02-02]: NSPanel with canJoinAllSpaces + fullScreenAuxiliary for fullscreen visibility
- [02-02]: .ultraThinMaterial background for floating indicator - native macOS vibrancy
- [03-01]: Option+Space as default hotkey (non-conflicting, easy to hold)
- [03-01]: Dual insertion strategy: AX first, clipboard+paste fallback
- [03-01]: 50ms delay before paste to ensure clipboard sync
- [03-02]: Text insertion after state update - UI updates first, then insert
- [03-02]: Insertion failure non-blocking - text remains on clipboard for manual paste
- [04-01]: LanguageMode enum uses rawValue as display strings (Auto/Vietnamese/English)
- [04-01]: whisperLanguageCode returns nil for auto-detect
- [04-01]: UserDefaults directly instead of @AppStorage in @Observable classes
- [04-02]: SF Symbols for status icons - consistent with macOS design language
- [04-02]: Auto-dismiss for transient states (error 3s, language 1.5s)
- [04-02]: StatusIndicatorState enum for type-safe UI state management
- [04-04]: SwiftData for history persistence - modern Apple framework
- [04-04]: 100-item history limit - prevents unbounded database growth
- [04-04]: TabView in Settings - accommodates History tab alongside existing controls
- [04-03]: WhisperModel struct for type-safe model metadata
- [04-03]: UserDefaults for selectedModel (not @AppStorage) to avoid @Observable conflict
- [04-03]: onDownloadProgress callback pattern for flexible UI updates

### Pending Todos

None.

### Blockers/Concerns

- [Resolved]: Text insertion edge cases in Electron apps tested - clipboard+paste fallback works
- [Note]: Using Whisper multilingual instead of PhoWhisper - lower Vietnamese accuracy but supports both languages
- [Note]: HotkeyService has separate statusPanel instance - acceptable for UI isolation

## Session Continuity

Last session: 2026-01-17T17:29:02Z
Stopped at: Completed 04-03-PLAN.md (Model Size Selection) - All plans complete
Resume file: None
