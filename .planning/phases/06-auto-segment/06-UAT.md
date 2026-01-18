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

total: 15
passed: 8
issues: 7
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

## Additional Bugs (Ad-hoc Testing)

### 11. Model Download Not Blocked
expected: Pressing hotkey during model download should block/wait or show appropriate feedback
result: issue
reported: "khi đang download model, nhấn phím tắt để transcript thì ko block downloading"
severity: major

### 12. No Pre-Download Model in Settings
expected: Settings should have option to pre-download models, not only trigger on first transcription
result: issue
reported: "ko có chức năng down sẵn model trong setting, chỉ trigger download khi nhấn transcript lần đầu"
severity: minor

### 13. Status Popup Layout Broken
expected: Status indicator popup should display text properly centered
result: issue
reported: "UI popup khi download xong mà transcript thì popup hiển thị lệch - chữ Recording bị xén ở trên, khoảng trống ở dưới"
severity: minor

### 14. Text Segments No Space Separator
expected: Auto-segment text insertions should have space between segments
result: issue
reported: "chữ vẫn bị dính ko có khoảng trắng - 'Xin chàoHôm nay là Chủ nhật'"
severity: major

### 15. Mode Switch Doesn't Reset Auto-Segment
expected: Switching to Hold-to-Talk should disable auto-segment mode completely
result: issue
reported: "sau khi chuyển về lại chế độ hold to talk vẫn bị kẹt ở chế độ toggle - khả năng cao do ko chuyển enable auto segment về off"
severity: major

## Gaps (Continued)

- truth: "Pressing hotkey during model download should block or show feedback"
  status: failed
  reason: "User reported: khi đang download model, nhấn phím tắt để transcript thì ko block downloading"
  severity: major
  test: 11
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Settings should allow pre-downloading models"
  status: failed
  reason: "User reported: ko có chức năng down sẵn model trong setting"
  severity: minor
  test: 12
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Status indicator popup should display text properly"
  status: failed
  reason: "User reported: popup hiển thị lệch - chữ Recording bị xén ở trên"
  severity: minor
  test: 13
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Auto-segment insertions should have space separator"
  status: failed
  reason: "User reported: chữ vẫn bị dính - 'Xin chàoHôm nay là Chủ nhật'"
  severity: major
  test: 14
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Switching to Hold-to-Talk should disable auto-segment"
  status: failed
  reason: "User reported: sau khi chuyển về hold to talk vẫn bị kẹt ở chế độ toggle"
  severity: major
  test: 15
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

## Enhancement Notes

- Previous feedback on Test 3: segments dính chữ - cần thêm space/separator giữa các đoạn (now logged as Bug #14)
