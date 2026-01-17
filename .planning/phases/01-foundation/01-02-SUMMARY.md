---
phase: 01-foundation
plan: 02
subsystem: services
tags: [swiftwhisper, whisper.cpp, phowhisper, smappservice, login-item, model-loading]

# Dependency graph
requires:
  - phase: 01-01
    provides: Menu bar app shell, AppState, PermissionManager
provides:
  - SwiftWhisper integration for PhoWhisper model loading
  - ModelManager with async GGML model loading
  - LaunchManager with SMAppService login item management
  - Model status UI in MenuBarView and SettingsView
affects: [02-01, 02-02, 03-01]

# Tech tracking
tech-stack:
  added:
    - SwiftWhisper 1.2.0 (whisper.cpp Swift wrapper)
  patterns:
    - "Async model loading with Task.detached for UI non-blocking"
    - "SMAppService.mainApp for login item management"
    - "Observable managers pattern (ModelManager, LaunchManager)"

key-files:
  created:
    - LocalTranscript/LocalTranscript/Services/ModelManager.swift
    - LocalTranscript/LocalTranscript/Services/LaunchManager.swift
  modified:
    - LocalTranscript/LocalTranscript.xcodeproj/project.pbxproj
    - LocalTranscript/LocalTranscript/Models/AppState.swift
    - LocalTranscript/LocalTranscript/Views/MenuBarView.swift
    - LocalTranscript/LocalTranscript/Views/SettingsView.swift

key-decisions:
  - "Lazy model loading: Load on first use, not app launch (prevents 3-5s startup freeze)"
  - "Model storage in Application Support: ~/Library/Application Support/LocalTranscript/"
  - "Manual load/unload buttons for Phase 1 testing (automatic in Phase 2)"

patterns-established:
  - "ModelManager pattern: Observable class with async loadModel(), isLoading, loadError, loadProgress"
  - "LaunchManager pattern: SMAppService.mainApp.register/unregister with system state sync"
  - "Settings sections: General (login item), Model (status), Permissions"

# Metrics
duration: 8min
completed: 2026-01-17
---

# Phase 01 Plan 02: Core Data Model Design Summary

**SwiftWhisper integration with async PhoWhisper GGML model loading and SMAppService login item management**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-17T14:22:00Z
- **Completed:** 2026-01-17T14:30:00Z
- **Tasks:** 3
- **Files modified:** 6 (2 created, 4 modified)

## Accomplishments

- SwiftWhisper 1.2.0 added as SPM dependency for whisper.cpp integration
- ModelManager with async model loading, progress tracking, and memory management
- LaunchManager with SMAppService for "Start at Login" toggle
- Model status display in both MenuBarView (dropdown) and SettingsView (Settings window)
- Open Model Folder button for quick access to download location

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SwiftWhisper dependency and implement ModelManager** - `aaed411` (feat)
2. **Task 2: Implement LaunchManager with SMAppService and user preferences** - `be5cb37` (feat)
3. **Task 3: Integrate model status into MenuBarView and test model loading** - `7d401fa` (feat)

## Files Created/Modified

- `LocalTranscript/Services/ModelManager.swift` - Async PhoWhisper GGML model loading with SwiftWhisper
- `LocalTranscript/Services/LaunchManager.swift` - SMAppService login item management
- `LocalTranscript/Models/AppState.swift` - Added modelManager and launchManager instances
- `LocalTranscript/Views/MenuBarView.swift` - Model status display and load/unload buttons
- `LocalTranscript/Views/SettingsView.swift` - General section (login toggle), Model section (status and download instructions)
- `LocalTranscript.xcodeproj/project.pbxproj` - SwiftWhisper package reference and new source files

## Decisions Made

- **Lazy loading pattern:** Model loads on first recording trigger (Phase 2), not at app launch. Prevents 3-5 second startup freeze. Manual buttons added for Phase 1 testing.
- **Application Support storage:** Model file expected at `~/Library/Application Support/LocalTranscript/ggml-phowhisper-medium.bin`. Directory created automatically on first access.
- **System state sync:** LaunchManager reads from SMAppService.mainApp.status on appear, since user can change login items in System Settings directly.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed without issues. Build succeeded on first attempt after each code change.

## User Setup Required

**Model file required for transcription.** The app expects the PhoWhisper GGML model at:
```
~/Library/Application Support/LocalTranscript/ggml-phowhisper-medium.bin
```

Download from: https://huggingface.co/dongxiat/ggml-PhoWhisper-medium/tree/main

The Settings UI provides an "Open Model Folder" button for quick access to the download location.

## Next Phase Readiness

- SwiftWhisper integration complete, ready for audio capture pipeline (Phase 2)
- Model loading infrastructure in place for Phase 2 automatic loading on first recording
- Login item management complete for app persistence requirement
- No blockers identified

---
*Phase: 01-foundation*
*Completed: 2026-01-17*
