---
status: complete
phase: 04-polish
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md, 04-04-SUMMARY.md, 04-05-SUMMARY.md]
started: 2026-01-18T01:00:00Z
updated: 2026-01-18T06:50:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Language Mode Picker in Settings
expected: Open Settings. A Language section shows a segmented picker with Auto/Vietnamese/English options. Selecting one saves immediately.
result: pass

### 2. Language Cycle Hotkey (Option+L)
expected: Press Option+L while app is running. Language mode cycles Auto → Vietnamese → English → Auto. A brief floating indicator shows the new language mode.
result: pass

### 3. Status Indicator - Recording State
expected: Start recording (hold/toggle hotkey). A floating indicator with red recording icon appears showing recording in progress.
result: pass

### 4. Status Indicator - Transcribing State
expected: Stop recording. Indicator changes to show waveform icon during transcription processing.
result: pass

### 5. Status Indicator - Error Display
expected: If an error occurs (e.g., no microphone permission), indicator shows error with exclamation icon, auto-dismisses after ~3 seconds.
result: pass

### 6. Model Picker in Settings
expected: Open Settings. A Model section shows a picker with 5 Whisper model sizes (tiny to large-v3) with their approximate sizes displayed.
result: pass

### 7. Model Download Progress
expected: Select a different model that isn't downloaded. Progress bar appears in Settings showing download progress. Status indicator also shows downloading state.
result: pass
note: "Re-tested after 04-05 gap closure fix. Model switching now triggers download with progress display."

### 8. History Tab in Settings
expected: Open Settings. A History tab is available alongside General. Clicking it shows list of past transcriptions with timestamps.
result: pass
note: "Re-tested after 04-05 gap closure fix. History tab icon now visible."
feedback: "UX suggestion: Clear All button in History tab creates visual confusion (looks like 3 tabs). Consider repositioning for v2."

### 9. Copy from History
expected: In History tab, right-click (or secondary click) a transcription entry. Context menu with "Copy" option appears. Selecting it copies text to clipboard.
result: pass

### 10. Delete from History
expected: In History tab, swipe left on an entry (or use delete action). Entry is removed from history list.
result: pass

### 11. History Auto-Save
expected: Complete a transcription. The transcribed text appears in History tab with correct timestamp and language mode.
result: pass
note: "Performance concern - timestamp updating every second may be resource-heavy. Consider optimization later."

## Summary

total: 11
passed: 11
issues: 0 (2 fixed by 04-05 gap closure)
pending: 0
skipped: 0

## Gaps

### Closed (by 04-05-PLAN.md)

- truth: "Progress bar appears in Settings showing download progress when selecting a new model"
  status: closed
  fix: "Removed @AppStorage, used computed Binding to call switchModel() directly"
  verified: 2026-01-18T06:50:00Z

- truth: "History tab is visible alongside General in Settings"
  status: closed
  fix: "Added @State selectedTab, TabView selection binding, explicit .tag() values"
  verified: 2026-01-18T06:50:00Z

### Post-UAT Polish

- feedback: "Clear All button in History tab creates visual confusion (looks like 3 tabs)"
  status: fixed
  fix: "Moved Clear All to fixed footer below list with Divider separator"
  verified: 2026-01-18T06:58:00Z
  test: 8
