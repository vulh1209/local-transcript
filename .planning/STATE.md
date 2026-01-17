# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-17)

**Core value:** Noi tieng Viet, ra text chinh xac, khong can internet.
**Current focus:** Phase 3 - System Integration (COMPLETE)

## Current Position

Phase: 3 of 4 (System Integration) - COMPLETE
Plan: 2 of 2 in current phase - COMPLETE
Status: Phase complete
Last activity: 2026-01-17 - Completed 03-02-PLAN.md (Service Wiring)

Progress: [######----] 67% (6 of 9 total plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 5 min
- Total execution time: 28 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 2/2 | 13 min | 6.5 min |
| 02-audio-transcription | 2/3 | 6 min | 3 min |
| 03-system-integration | 2/2 | 9 min | 4.5 min |

**Recent Trend:**
- Last 5 plans: 02-01 (2 min), 02-02 (4 min), 03-01 (4 min), 03-02 (5 min)
- Trend: Fast execution for well-researched plans

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

### Pending Todos

None.

### Blockers/Concerns

- [Resolved]: Text insertion edge cases in Electron apps tested - clipboard+paste fallback works
- [Note]: Using Whisper multilingual instead of PhoWhisper - lower Vietnamese accuracy but supports both languages

## Session Continuity

Last session: 2026-01-17T16:35:00Z
Stopped at: Completed 03-02-PLAN.md (Phase 3 complete)
Resume file: None
