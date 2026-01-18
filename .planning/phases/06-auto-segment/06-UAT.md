---
status: diagnosed
phase: 06-auto-segment
source: 06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-04-SUMMARY.md
started: 2026-01-18T02:30:00Z
updated: 2026-01-18T03:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Settings Mode Picker
expected: Settings > Auto-Segment section shows picker with Manual/Auto options
result: pass

### 2. Silence Threshold Slider
expected: When Auto mode selected, slider appears below picker (1-5 seconds range). When Manual selected, slider hidden.
result: pass

### 3. Continuous Recording Start (RETEST)
expected: In Auto mode, transcribed segment text should be inserted at cursor position (not just saved to history)
result: pass
note: "User feedback - segments dính chữ, cần thêm space/separator giữa các đoạn (enhancement)"

### 4. Segment Detection Flash (RETEST)
expected: After segment transcription completes, status indicator should transition properly (not get stuck on "transcribing")
result: pass

### 5. Pending Segments Count (RETEST)
expected: During continuous recording, status indicator shows current state (not stuck on transcribing)
result: pass

### 6. Auto-Insert on Silence (RETEST)
expected: Auto-insert text at cursor after silence detection - text should appear where you're typing, not just in history
result: pass

### 7. Whisper Hallucination on Long Silence
expected: Extended silence should not produce hallucinated text
result: issue
reported: "Nếu mà silent lâu quá thì sẽ ra một đoạn text là hãy subscribe kênh Ghiền Mì Gõ"
severity: major

### 8. Auto-Segment UI Visibility
expected: Auto-segment settings should only show when Toggle Mode is enabled
result: issue
reported: "Auto-segment chỉ hiển thị và cho setup khi bật toggle mode chứ ko phải luôn hiển thị"
severity: minor

### 9. Manual Mode Redundancy in Toggle Mode
expected: When Toggle Mode is on, Manual option in auto-segment picker should not appear (redundant)
result: issue
reported: "khi bật toggle mode thì sẽ ko có manual mode trong auto-segment nữa"
severity: minor

### 10. Mode Switch Does Not Stop Recording
expected: Switching from Toggle Mode to Hold-to-Talk should stop any active recording
result: issue
reported: "khi switch về hold to talk ko tự stop recording của toggle"
severity: major

## Summary

total: 10
passed: 6
issues: 4
pending: 0
skipped: 0

## Gaps

- truth: "Extended silence should not produce hallucinated text"
  status: failed
  reason: "User reported: Nếu mà silent lâu quá thì sẽ ra một đoạn text là hãy subscribe kênh Ghiền Mì Gõ"
  severity: major
  test: 7
  root_cause: "No audio energy validation - handleSegment() only checks !samples.isEmpty. WhisperKit metrics (noSpeechProb, avgLogprob) ignored."
  artifacts:
    - path: "LocalTranscript/LocalTranscript/Services/TranscriptionService.swift"
      issue: "Line 282: No RMS energy check before transcription. Line 450: Discards noSpeechProb metric"
  missing:
    - "Add RMS energy threshold check (reject if rms < 0.01)"
    - "Add post-filter using WhisperKit noSpeechProb > 0.7"
  debug_session: ".claude/cache/agents/debug-agent/latest-output.md"

- truth: "Auto-segment settings should only show when Toggle Mode is enabled"
  status: failed
  reason: "User reported: Auto-segment chỉ hiển thị và cho setup khi bật toggle mode chứ ko phải luôn hiển thị"
  severity: minor
  test: 8
  root_cause: "Auto-Segment Section at line 60 has no conditional rendering based on appState.hotkeyService.mode"
  artifacts:
    - path: "LocalTranscript/LocalTranscript/Views/SettingsView.swift"
      issue: "Line 60: Section rendered unconditionally"
  missing:
    - "Wrap Section with: if appState.hotkeyService.mode == .toggle"
  debug_session: ".claude/cache/agents/debug-agent/latest-output.md"

- truth: "Manual option should not appear in auto-segment when Toggle Mode is on"
  status: failed
  reason: "User reported: khi bật toggle mode thì sẽ ko có manual mode trong auto-segment nữa"
  severity: minor
  test: 9
  root_cause: "Picker uses SegmentMode.allCases showing both manual/auto. Since section only shows in toggle mode, picker is redundant."
  artifacts:
    - path: "LocalTranscript/LocalTranscript/Views/SettingsView.swift"
      issue: "Line 62-68: Picker shows all cases including manual"
  missing:
    - "Replace picker with toggle switch 'Enable Auto-Segment' or remove picker entirely"
  debug_session: ".claude/cache/agents/debug-agent/latest-output.md"

- truth: "Switching from Toggle Mode to Hold-to-Talk should stop active recording"
  status: failed
  reason: "User reported: khi switch về hold to talk ko tự stop recording của toggle"
  severity: major
  test: 10
  root_cause: "HotkeyService.mode setter only calls rebindHandlers(), does not stop active recording first"
  artifacts:
    - path: "LocalTranscript/LocalTranscript/Services/HotkeyService.swift"
      issue: "Lines 18-23: mode.didSet missing stop-recording logic"
  missing:
    - "Add to mode.didSet: if isRecording { isRecording = false; Task { await onStop?() } }"
  debug_session: ".claude/cache/agents/debug-agent/latest-output.md"

## Enhancement Notes

- User feedback on Test 3: segments dính chữ vào nhau - cần thêm space/separator giữa các đoạn (future enhancement for v1.2)
