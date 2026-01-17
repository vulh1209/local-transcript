---
phase: 04-polish
plan: 01
subsystem: ui
tags: [swiftui, appstorage, keyboardshortcuts, whisperkit, language-mode]

# Dependency graph
requires:
  - phase: 03-system-integration
    provides: TranscriptionService with DecodingOptions
provides:
  - LanguageMode enum with whisper language codes
  - Language mode picker in Settings
  - Option+L hotkey for language cycling
  - StatusIndicatorPanel feedback on language change
affects: [04-02, 04-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - UserDefaults for language mode persistence
    - StatusIndicatorPanel for brief visual feedback

key-files:
  created:
    - LocalTranscript/LocalTranscript/Models/LanguageMode.swift
  modified:
    - LocalTranscript/LocalTranscript/Services/TranscriptionService.swift
    - LocalTranscript/LocalTranscript/Services/HotkeyService.swift
    - LocalTranscript/LocalTranscript/Views/SettingsView.swift
    - LocalTranscript/LocalTranscript.xcodeproj/project.pbxproj

key-decisions:
  - "LanguageMode enum uses rawValue as display strings (Auto/Vietnamese/English)"
  - "whisperLanguageCode returns nil for auto-detect, letting Whisper decide"
  - "UserDefaults directly instead of @AppStorage in @Observable classes"

patterns-established:
  - "Pattern: StatusIndicatorPanel.updateState(.languageChanged(mode)) for brief feedback"
  - "Pattern: Task { @MainActor in } wrapper for MainActor methods from KeyboardShortcuts callbacks"

# Metrics
duration: 6min
completed: 2026-01-18
---

# Phase 4 Plan 01: Language Mode Selection Summary

**LanguageMode enum with Auto/Vietnamese/English, Settings picker, and Option+L hotkey cycling with StatusIndicatorPanel feedback**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-17T17:16:50Z
- **Completed:** 2026-01-17T17:22:53Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Created LanguageMode enum with auto/vietnamese/english cases and whisperLanguageCode property
- Added language mode picker to Settings with segmented style
- Implemented Option+L hotkey to cycle through language modes
- Shows brief StatusIndicatorPanel feedback when language mode changes
- TranscriptionService uses selected language mode in DecodingOptions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create LanguageMode enum and add to TranscriptionService** - `421db95` (feat)
2. **Task 2: Add language mode picker and cycle hotkey** - `e977ba6` (feat)
3. **Task 3: Test language mode persistence and transcription** - (verification only, no commit needed)

## Files Created/Modified
- `LocalTranscript/LocalTranscript/Models/LanguageMode.swift` - LanguageMode enum with auto/vietnamese/english and whisperLanguageCode
- `LocalTranscript/LocalTranscript/Services/TranscriptionService.swift` - Uses languageMode in DecodingOptions, updated to use StatusIndicatorPanel
- `LocalTranscript/LocalTranscript/Services/HotkeyService.swift` - Added cycleLanguage hotkey (Option+L), cycleLanguageMode() method
- `LocalTranscript/LocalTranscript/Views/SettingsView.swift` - Added Language section with picker and hotkey recorder
- `LocalTranscript/LocalTranscript.xcodeproj/project.pbxproj` - Added LanguageMode.swift to project

## Decisions Made
- Used rawValue strings for LanguageMode display ("Auto", "Vietnamese", "English") - cleaner than separate display property
- whisperLanguageCode returns nil for auto-detect mode - lets Whisper's internal language detection work
- Used UserDefaults directly in @Observable classes instead of @AppStorage to avoid macro conflicts
- Task { @MainActor in } wrapper for cycleLanguageMode() call from KeyboardShortcuts callback

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated TranscriptionService to use StatusIndicatorPanel**
- **Found during:** Task 1 (Build verification)
- **Issue:** TranscriptionService referenced old FloatingIndicatorPanel which was renamed to StatusIndicatorPanel
- **Fix:** Changed floatingPanel property to statusPanel, updated to use StatusIndicatorPanel with updateState() API
- **Files modified:** LocalTranscript/LocalTranscript/Services/TranscriptionService.swift
- **Verification:** Build succeeds
- **Committed in:** 421db95 (Task 1 commit)

**2. [Rule 3 - Blocking] Fixed @AppStorage conflict with @Observable macro**
- **Found during:** Task 1 (Build verification)
- **Issue:** @AppStorage property wrapper conflicts with @Observable macro in TranscriptionService
- **Fix:** Linter auto-corrected to use UserDefaults directly with @ObservationIgnored
- **Files modified:** LocalTranscript/LocalTranscript/Services/TranscriptionService.swift
- **Verification:** Build succeeds
- **Committed in:** 421db95 (Task 1 commit)

**3. [Rule 3 - Blocking] Fixed MainActor isolation in KeyboardShortcuts callback**
- **Found during:** Task 2 (Build verification)
- **Issue:** cycleLanguageMode() is @MainActor isolated, cannot call directly from nonisolated KeyboardShortcuts callback
- **Fix:** Wrapped call in Task { @MainActor in } block
- **Files modified:** LocalTranscript/LocalTranscript/Services/HotkeyService.swift
- **Verification:** Build succeeds
- **Committed in:** e977ba6 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (all blocking issues)
**Impact on plan:** All auto-fixes necessary for code to compile. No scope creep.

## Issues Encountered
- None beyond the auto-fixed blocking issues above

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Language mode selection complete and functional
- Ready for Plan 02 (Status UI Updates) which will enhance the StatusIndicatorPanel further
- Option+L hotkey can be used immediately for language cycling

---
*Phase: 04-polish*
*Completed: 2026-01-18*
