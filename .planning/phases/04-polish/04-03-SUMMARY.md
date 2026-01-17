---
phase: 04-polish
plan: 03
subsystem: ui
tags: [whisperkit, model-selection, settings, download-progress]

# Dependency graph
requires:
  - phase: 04-02
    provides: StatusIndicatorPanel with downloading state support
  - phase: 01-02
    provides: ModelManager lazy loading pattern
provides:
  - Model size selection (5 Whisper variants)
  - Download progress tracking in Settings
  - Download progress in StatusIndicatorPanel
  - Model switching with unload/reload
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - WhisperKit.download for model download with progress
    - UserDefaults for selectedModel persistence in @Observable classes
    - onDownloadProgress callback pattern for UI updates

key-files:
  created: []
  modified:
    - LocalTranscript/LocalTranscript/Services/ModelManager.swift
    - LocalTranscript/LocalTranscript/Views/SettingsView.swift
    - LocalTranscript/LocalTranscript/Services/TranscriptionService.swift

key-decisions:
  - "WhisperModel struct for type-safe model metadata"
  - "UserDefaults directly for selectedModel (not @AppStorage) to avoid @Observable conflict"
  - "onDownloadProgress callback pattern for flexible UI updates"

patterns-established:
  - "WhisperKit.download with progressCallback for model downloads"
  - "Model switch = unload + load (clean state transition)"

# Metrics
duration: 4min
completed: 2026-01-18
---

# Phase 4 Plan 3: Model Size Selection Summary

**Model picker in Settings with 5 Whisper sizes (tiny to large-v3) and real-time download progress**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-17T17:25:49Z
- **Completed:** 2026-01-17T17:29:02Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added WhisperModel struct with id, name, size, and description fields
- 5 model sizes available: tiny (~40MB) to large-v3 (~1.5GB)
- Model picker in Settings with size/description display
- Download progress shown in both Settings (ProgressView) and StatusIndicatorPanel
- Selected model persists across app restarts via UserDefaults

## Task Commits

Each task was committed atomically:

1. **Task 1: Enhance ModelManager with model selection and download progress** - `3301e9b` (feat)
2. **Task 2: Add model picker to Settings with download progress** - `c6ee489` (feat)
3. **Task 3: Wire download progress to StatusIndicatorPanel** - `0a44416` (feat)

## Files Created/Modified
- `LocalTranscript/LocalTranscript/Services/ModelManager.swift` - WhisperModel struct, availableModels, selectedModel, downloadProgress, switchModel
- `LocalTranscript/LocalTranscript/Views/SettingsView.swift` - Model picker with onChange, download progress bar
- `LocalTranscript/LocalTranscript/Services/TranscriptionService.swift` - Wire onDownloadProgress to StatusIndicatorPanel

## Decisions Made
- **WhisperModel struct**: Type-safe model metadata with id, name, size, description
- **UserDefaults for selectedModel**: Avoid @AppStorage conflict with @Observable macro
- **onDownloadProgress callback**: Flexible pattern allowing any UI to subscribe to progress updates
- **WhisperKit.download API**: Use explicit download then initialize (instead of auto-download in WhisperKit init) for progress tracking

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] WhisperKit.download returns URL, not String**
- **Found during:** Task 1 (ModelManager enhancement)
- **Issue:** Plan showed `modelFolder` parameter as String but WhisperKit.download returns URL
- **Fix:** Used `modelFolder.path` to convert URL to String path
- **Files modified:** ModelManager.swift
- **Verification:** Build succeeded
- **Committed in:** 3301e9b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** API type mismatch fix was necessary for compilation. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Model selection complete with full UI integration
- Users can choose between speed (tiny) and accuracy (large-v3)
- Download progress visible during model changes and first recording

---
*Phase: 04-polish*
*Completed: 2026-01-18*
