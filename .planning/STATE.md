# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-17)

**Core value:** Noi tieng Viet, ra text chinh xac, khong can internet.
**Current focus:** Phase 2 - Audio + Transcription

## Current Position

Phase: 2 of 4 (Audio + Transcription)
Plan: 1 of 3 in current phase
Status: In progress
Last activity: 2026-01-17 - Completed 02-01-PLAN.md (Audio Recording Service)

Progress: [###-------] 33% (3 of 9 total plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 5 min
- Total execution time: 15 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 2/2 | 13 min | 6.5 min |
| 02-audio-transcription | 1/3 | 2 min | 2 min |

**Recent Trend:**
- Last 5 plans: 01-01 (5 min), 01-02 (8 min), 02-01 (2 min)
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

### Pending Todos

None.

### Blockers/Concerns

- [Research]: CoreML model conversion for PhoWhisper may need debugging
- [Research]: Text insertion edge cases in Electron apps (VSCode, Slack) need testing

## Session Continuity

Last session: 2026-01-17T14:53:20Z
Stopped at: Completed 02-01-PLAN.md
Resume file: None
