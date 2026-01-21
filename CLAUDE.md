# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**LocalTranscript (VoiceType)** is a macOS menu bar app for Vietnamese/English speech-to-text. Users hold a hotkey to record speech, release to transcribe, and text is automatically inserted at cursor position. Runs 100% offline using WhisperKit with local Whisper models.

**v1.1 features:** Auto-translate (Vietnamese→English via WhisperKit) and Auto-segment (VAD-based hands-free dictation with FluidAudio SileroVAD).

## Build Commands

```bash
# Open in Xcode
open LocalTranscript/LocalTranscript.xcodeproj

# Build from command line
xcodebuild -project LocalTranscript/LocalTranscript.xcodeproj -scheme LocalTranscript -configuration Debug build

# Build and run
xcodebuild -project LocalTranscript/LocalTranscript.xcodeproj -scheme LocalTranscript -configuration Debug build && open ~/Library/Developer/Xcode/DerivedData/LocalTranscript-*/Build/Products/Debug/LocalTranscript.app
```

## Architecture

### App Structure

```
LocalTranscript/LocalTranscript/
├── LocalTranscriptApp.swift   # @main entry, MenuBarExtra + Settings scenes
├── Models/
│   ├── AppState.swift         # @Observable central state, owns all services
│   ├── LanguageMode.swift     # Auto/Vietnamese/English enum
│   ├── SegmentMode.swift      # Manual/Auto-segment enum
│   └── StatusIndicatorState.swift  # Recording/transcribing/error states
├── Services/
│   ├── TranscriptionService.swift  # Coordinates recording→transcription→insertion flow
│   ├── AudioRecorder.swift         # AVAudioEngine capture, 16kHz conversion, VAD integration
│   ├── HotkeyService.swift         # KeyboardShortcuts, hold-to-talk/toggle modes
│   ├── TextInsertionService.swift  # AXUIElement + clipboard fallback
│   ├── ModelManager.swift          # WhisperKit model loading
│   ├── HistoryManager.swift        # SwiftData transcription history
│   ├── VADService.swift            # FluidAudio SileroVAD for auto-segment
│   ├── CircularAudioBuffer.swift   # 60s thread-safe audio buffer
│   └── TranscriptionQueue.swift    # FIFO queue for sequential transcription
├── Utilities/
│   └── AudioFeedback.swift         # System sounds for recording state
├── Design/
│   ├── GlassDesign.swift           # Glass morphism design system
│   └── GlassComponents.swift       # Reusable glass UI components
└── Views/
    ├── MenuBarView.swift           # Menu bar dropdown content
    ├── SettingsView.swift          # Settings window with tabs
    ├── StatusIndicatorPanel.swift  # Floating recording/status overlay
    ├── HistoryView.swift           # Transcription history list
    └── FloatingIndicator.swift     # Floating indicator window management
```

### Data Flow

**Manual mode (hold-to-talk/toggle):**
1. **HotkeyService** captures global hotkey (Option+Space) via KeyboardShortcuts
2. **AppState** routes to **TranscriptionService.startRecording()**
3. **AudioRecorder** captures mic audio, converts to 16kHz mono Float32
4. On hotkey release, **TranscriptionService.stopRecording()** gets samples
5. **ModelManager.whisperKit** runs ML inference (WhisperKit)
6. **TextInsertionService** inserts result via AXUIElement or clipboard+Cmd+V fallback
7. **HistoryManager** saves transcription record

**Auto-segment mode (continuous VAD-based):**
1. **TranscriptionService.startContinuousRecording()** starts recording with VAD active
2. **AudioRecorder** feeds 4096-sample chunks (256ms) to **VADService**
3. **VADService** (FluidAudio SileroVAD) detects speech end after silence threshold (default 2s)
4. **CircularAudioBuffer** provides 60s of audio history for segment extraction
5. **TranscriptionQueue** processes segments FIFO, max depth 5
6. Text inserted progressively as segments complete

### Key Patterns

- **@Observable macro**: All services use Swift's @Observable instead of ObservableObject
- **Hybrid SwiftUI/AppKit**: MenuBarExtra for menu bar, NSPanel subclass for floating indicator
- **Non-sandboxed**: Required for AXUIElement text insertion and CGEventTap global hotkeys
- **Lazy model loading**: Whisper model loads on first transcription, shows download progress
- **Actor isolation**: VADService and TranscriptionQueue are actors for thread safety
- **Hallucination prevention**: RMS energy threshold (0.01) + WhisperKit metrics filtering (noSpeechProb, avgLogprob, compressionRatio)

## Critical Constraints

- **macOS 14+ required**: Uses MenuBarExtra and modern SwiftUI features
- **Must be non-sandboxed**: Accessibility API and global hotkeys blocked in sandbox
- **WhisperKit not SwiftWhisper**: Project uses WhisperKit for CoreML optimization and auto model download
- **16kHz audio**: Whisper requires 16kHz mono Float32 samples
- **VAD chunk size**: FluidAudio SileroVAD requires 4096 samples (256ms at 16kHz)

## Default Hotkeys

- **Option+Space**: Hold to record, release to transcribe (configurable)
- **Option+L**: Cycle language mode (Auto→Vietnamese→English)

## Required Permissions

The app requests these at runtime:
- Microphone (NSMicrophoneUsageDescription)
- Accessibility (AXIsProcessTrusted)
- Input Monitoring (CGPreflightListenEventAccess)

## Planning Documentation

The `.planning/` directory contains project planning artifacts:
- `PROJECT.md` - Requirements and decisions
- `STATE.md` - Current milestone/phase status
- `milestones/` - Per-milestone roadmaps and requirements
- `phases/` - Per-phase plans, research, and verification
- `research/` - Stack, architecture, and pitfall research
