# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-17)

**Core value:** Noi tieng Viet, ra text chinh xac, khong can internet.
**Current focus:** Phase 3 - System Integration

## Current Position

Phase: 3 of 4 (System Integration)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-01-17 - Completed 03-01-PLAN.md (Core Services)

Progress: [#####-----] 56% (5 of 9 total plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: 5 min
- Total execution time: 23 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 2/2 | 13 min | 6.5 min |
| 02-audio-transcription | 2/3 | 6 min | 3 min |
| 03-system-integration | 1/2 | 4 min | 4 min |

**Recent Trend:**
- Last 5 plans: 01-02 (8 min), 02-01 (2 min), 02-02 (4 min), 03-01 (4 min)
- Trend: Fast execution for well-researched plans

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Non-sandboxed distribution (Accessibility API, CGEventTap require it)
- [Roadmap]: PhoWhisper from day one (4.97% WER vs ~15-20% for generic Whisper)
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

### Pending Todos

None.

### Blockers/Concerns

- [Research]: CoreML model conversion for PhoWhisper may need debugging
- [Research]: Text insertion edge cases in Electron apps (VSCode, Slack) need testing

## Session Continuity

Last session: 2026-01-17T16:24:38Z
Stopped at: Completed 03-01-PLAN.md
Resume file: None
