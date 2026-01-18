# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**LocalTranscript (VoiceType)** is a macOS menu bar app for Vietnamese/English speech-to-text. Users hold a hotkey to record speech, release to transcribe, and text is automatically inserted at cursor position. Runs 100% offline using WhisperKit with local Whisper models.

## Build Commands

```bash
# Open in Xcode
open LocalTranscript/LocalTranscript.xcodeproj

# Build from command line
xcodebuild -project LocalTranscript/LocalTranscript.xcodeproj -scheme LocalTranscript -configuration Debug build

# Run the app
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
│   └── StatusIndicatorState.swift  # Recording/transcribing/error states
├── Services/
│   ├── TranscriptionService.swift  # Coordinates recording→transcription→insertion flow
│   ├── AudioRecorder.swift         # AVAudioEngine capture, 16kHz conversion
│   ├── HotkeyService.swift         # KeyboardShortcuts, hold-to-talk/toggle modes
│   ├── TextInsertionService.swift  # AXUIElement + clipboard fallback
│   ├── ModelManager.swift          # WhisperKit model loading
│   └── HistoryManager.swift        # SwiftData transcription history
└── Views/
    ├── MenuBarView.swift           # Menu bar dropdown content
    ├── SettingsView.swift          # Settings window with tabs
    ├── StatusIndicatorPanel.swift  # Floating recording/status overlay
    └── HistoryView.swift           # Transcription history list
```

### Data Flow

1. **HotkeyService** captures global hotkey (Option+Space) via KeyboardShortcuts
2. **AppState** routes to **TranscriptionService.startRecording()**
3. **AudioRecorder** captures mic audio, converts to 16kHz mono Float32
4. On hotkey release, **TranscriptionService.stopRecording()** gets samples
5. **ModelManager.whisperKit** runs ML inference (WhisperKit)
6. **TextInsertionService** inserts result via AXUIElement or clipboard+Cmd+V fallback
7. **HistoryManager** saves transcription record

### Key Patterns

- **@Observable macro**: All services use Swift's @Observable instead of ObservableObject
- **Hybrid SwiftUI/AppKit**: MenuBarExtra for menu bar, NSPanel subclass for floating indicator
- **Non-sandboxed**: Required for AXUIElement text insertion and CGEventTap global hotkeys
- **Lazy model loading**: Whisper model loads on first transcription, shows download progress

## Critical Constraints

- **macOS 14+ required**: Uses MenuBarExtra and modern SwiftUI features
- **Must be non-sandboxed**: Accessibility API and global hotkeys blocked in sandbox
- **WhisperKit not SwiftWhisper**: Project uses WhisperKit for CoreML optimization and auto model download
- **16kHz audio**: Whisper requires 16kHz mono Float32 samples

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
- `ROADMAP.md` - Phase breakdown and progress
- `phases/` - Per-phase plans, research, and verification
- `research/` - Stack, architecture, and pitfall research
