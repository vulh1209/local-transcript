---
status: complete
phase: 05-auto-translate
source: [05-01-SUMMARY.md]
started: 2026-01-18T11:00:00Z
updated: 2026-01-18T11:05:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Translate Toggle in Settings
expected: Open Settings window. There's a "Translation" section with a toggle labeled "Translate to English". Below it should be explanation text about Vietnamese speech being output as English text.
result: pass

### 2. Translate Mode Works
expected: Enable translate toggle, speak Vietnamese, release hotkey. The output text should be in English (translated from Vietnamese speech).
result: pass

### 3. Transcribe Mode Still Works
expected: Disable translate toggle, speak Vietnamese, release hotkey. The output text should be in Vietnamese (not translated).
result: pass

### 4. Translated Entry Shows Blue Badge
expected: After a translated transcription, open History. The entry should show a blue "EN" badge to indicate it was translated.
result: issue
reported: "history unavaiable"
severity: major

### 5. Non-Translated Entry Has No Badge
expected: After a non-translated transcription, open History. The entry should NOT show the blue "EN" badge.
result: skipped
reason: Blocked by same history unavailable issue

## Summary

total: 5
passed: 3
issues: 1
pending: 0
skipped: 1

## Gaps

- truth: "After a translated transcription, open History. The entry should show a blue 'EN' badge to indicate it was translated."
  status: failed
  reason: "User reported: history unavaiable"
  severity: major
  test: 4
  artifacts: []
  missing: []
