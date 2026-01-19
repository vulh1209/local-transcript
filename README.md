# LocalTranscript (VoiceType)

macOS menu bar app for Vietnamese/English speech-to-text dictation. Hold a hotkey, speak, release — text appears at your cursor. Runs 100% offline using WhisperKit on Apple Silicon.

## Features

- **Hold-to-talk**: Hold Option+Space to record, release to transcribe
- **Toggle mode**: Press to start recording, press again to stop
- **Universal text insertion**: Works in any app via Accessibility API
- **100% offline**: All processing on-device with CoreML-optimized Whisper models
- **Vietnamese + English**: Supports both languages with automatic detection
- **Menu bar app**: Minimal UI, always accessible from menu bar
- **Floating indicator**: Visual feedback during recording/transcription
- **Transcription history**: Review, copy, or delete past transcriptions
- **Customizable**: Choose hotkey, model size, language mode

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3)
- ~1-4 GB disk space for Whisper models (varies by model size)

## Installation

### Download Release

Download the latest `.dmg` from [Releases](https://github.com/vulh1209/local-transcript/releases) and drag to Applications.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/vulh1209/local-transcript.git
cd local-transcript

# Open in Xcode
open LocalTranscript/LocalTranscript.xcodeproj

# Or build from command line
xcodebuild -project LocalTranscript/LocalTranscript.xcodeproj \
  -scheme LocalTranscript \
  -configuration Release \
  build
```

## Usage

1. **Launch the app** — appears in menu bar with microphone icon
2. **Grant permissions** when prompted:
   - Microphone access (for recording)
   - Accessibility access (for text insertion)
3. **Hold Option+Space** and speak
4. **Release** — text is inserted at cursor

### Hotkeys

| Hotkey | Action |
|--------|--------|
| Option+Space | Hold to record, release to transcribe |
| Option+L | Cycle language mode (Auto → Vietnamese → English) |

### Settings

Click the menu bar icon → Settings to configure:
- **Hotkey**: Change the recording hotkey
- **Mode**: Hold-to-talk or toggle on/off
- **Model**: Choose Whisper model size (tiny/base/small/medium/large)
- **Language**: Auto-detect, Vietnamese only, or English only
- **Launch at login**: Start automatically on login

## Architecture

```
LocalTranscript/
├── LocalTranscriptApp.swift    # App entry, MenuBarExtra + Settings
├── Models/
│   ├── AppState.swift          # Central state management
│   ├── LanguageMode.swift      # Auto/Vietnamese/English
│   └── StatusIndicatorState.swift
├── Services/
│   ├── TranscriptionService.swift  # Recording → transcription → insertion
│   ├── AudioRecorder.swift         # AVAudioEngine, 16kHz capture
│   ├── HotkeyService.swift         # Global hotkey handling
│   ├── TextInsertionService.swift  # AXUIElement + clipboard fallback
│   ├── ModelManager.swift          # WhisperKit model loading
│   └── HistoryManager.swift        # SwiftData persistence
└── Views/
    ├── MenuBarView.swift           # Menu bar dropdown
    ├── SettingsView.swift          # Settings window
    ├── StatusIndicatorPanel.swift  # Floating recording overlay
    └── HistoryView.swift           # Transcription history
```

### Tech Stack

- **SwiftUI** with MenuBarExtra for menu bar integration
- **WhisperKit** for CoreML-optimized speech recognition
- **KeyboardShortcuts** for global hotkey handling
- **SwiftData** for transcription history
- **Accessibility API** for text insertion into any app

## Permissions

The app requires these permissions:

| Permission | Why |
|------------|-----|
| Microphone | Record speech for transcription |
| Accessibility | Insert text into other applications |
| Input Monitoring | Detect global hotkey presses |

The app runs **non-sandboxed** because Accessibility API and global hotkeys require it.

## Privacy

- All audio processing happens locally on your Mac
- No audio data is ever sent to any server
- Transcription history stored locally in SwiftData
- No analytics or telemetry

## Troubleshooting

**Text not inserting in some apps (Electron apps like VS Code, Slack)**

These apps don't fully support Accessibility API. The app automatically falls back to clipboard paste (Cmd+V). Your clipboard is restored after insertion.

**Model download stuck**

WhisperKit downloads models on first use. Check internet connection and try a smaller model first (tiny/base).

**Hotkey not working**

Go to System Settings → Privacy & Security → Input Monitoring and ensure LocalTranscript is enabled.

## Contributing

Contributions welcome. Please open an issue first to discuss proposed changes.

## License

MIT License - see [LICENSE](LICENSE) for details.
