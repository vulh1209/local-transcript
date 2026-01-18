---
status: complete
phase: 06-auto-segment
source: 06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-04-SUMMARY.md, 06-05-SUMMARY.md
started: 2026-01-18T03:45:00Z
updated: 2026-01-18T04:00:00Z
retest: true
previous_issues: 4 (Tests 7-10)
---

## Current Test

[testing complete]

## Tests

### 1. Auto-Segment UI Visibility
expected: Auto-Segment settings section only visible when Toggle Mode is selected. Hidden in Hold-to-Talk mode.
result: pass

### 2. Auto-Segment Toggle Switch
expected: In Toggle Mode, Auto-Segment section shows a toggle switch (not a picker). Enable/disable auto-segment with single tap.
result: pass

### 3. Silence Threshold Slider
expected: When Auto-Segment enabled, slider appears below (1-5 seconds range, 0.5s steps). When disabled, slider hidden.
result: pass

### 4. Continuous Recording Start
expected: With Auto-Segment enabled, press hotkey to start recording. Status indicator shows "Listening..." state (not transcribing).
result: issue
reported: "not, still 'recording'"
severity: minor

### 5. Auto-Insert on Silence
expected: Speak, then stay silent for threshold duration. Text should be transcribed AND inserted at cursor position automatically.
result: pass

### 6. Status Indicator Transitions
expected: After segment transcription completes, status indicator returns to "Recording" (not stuck on "Transcribing").
result: pass

### 7. Whisper Hallucination Prevention
expected: Start auto-segment, stay completely silent for extended period (10+ seconds). Should NOT produce hallucinated text like "subscribe to channel" etc.
result: issue
reported: "vẫn bị ảo tưởng khi không nói gì, dù xài model large"
severity: major

### 8. Pending Segments Queue
expected: While one segment is transcribing, speak again to queue another. Status should show pending count if applicable.
result: pass

### 9. Mode Switch Stops Recording
expected: Start recording in Toggle Mode. Switch Hotkey Mode to "Hold to Talk". Active recording should stop immediately.
result: pass

### 10. Manual Mode Still Works
expected: Disable Auto-Segment (or use Hold-to-Talk mode). Hold hotkey, speak, release. Traditional manual transcription works as before.
result: pass

## Summary

total: 10
passed: 8
issues: 2
pending: 0
skipped: 0

## Gaps

- truth: "Status indicator shows 'Listening...' state in continuous recording mode"
  status: failed
  reason: "User reported: not, still 'recording'"
  severity: minor
  test: 4
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Extended silence should not produce hallucinated text"
  status: failed
  reason: "User reported: vẫn bị ảo tưởng khi không nói gì, dù xài model large"
  severity: major
  test: 7
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

## Enhancement Notes

- Previous feedback on Test 3: segments dính chữ - cần thêm space/separator giữa các đoạn (future enhancement for v1.2)
