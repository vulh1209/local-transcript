# Architecture Research

**Domain:** macOS Speech-to-Text Menu Bar Application
**Researched:** 2026-01-17
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
+------------------------------------------------------------------+
|                          User Interface Layer                      |
|------------------------------------------------------------------|
|  +------------------+  +------------------+  +------------------+  |
|  |   Menu Bar App   |  | Floating Overlay |  |  Settings Panel  |  |
|  |  (NSStatusItem)  |  |    (NSPanel)     |  |    (SwiftUI)     |  |
|  +--------+---------+  +--------+---------+  +--------+---------+  |
|           |                     |                     |            |
+-----------+---------------------+---------------------+------------+
            |                     |                     |
+-----------v---------------------v---------------------v------------+
|                        Application Core Layer                      |
|------------------------------------------------------------------|
|  +------------------+  +------------------+  +------------------+  |
|  |  Hotkey Manager  |  |  Recording Mgr   |  |   State Manager  |  |
|  |   (CGEventTap)   |  | (AVAudioEngine)  |  |   (Combine/      |  |
|  |                  |  |                  |  |    Observable)   |  |
|  +--------+---------+  +--------+---------+  +--------+---------+  |
|           |                     |                     |            |
+-----------+---------------------+---------------------+------------+
            |                     |                     |
+-----------v---------------------v---------------------v------------+
|                      Processing Layer                              |
|------------------------------------------------------------------|
|  +-----------------------------------------------------------+   |
|  |                   Transcription Engine                     |   |
|  |  +-----------+  +-----------+  +-----------+              |   |
|  |  | WhisperKit|  |Audio Proc.|  |Vietnamese |              |   |
|  |  | /whisper. |  |(Resample, |  |  Model    |              |   |
|  |  |   cpp     |  | Convert)  |  | (vi-large)|              |   |
|  |  +-----------+  +-----------+  +-----------+              |   |
|  +-----------------------------------------------------------+   |
+------------------------------------------------------------------+
            |
+-----------v---------------------+
|      System Integration Layer   |
|---------------------------------|
|  +------------------+  +------------------+
|  | Text Insertion   |  | Clipboard        |
|  | (AXUIElement)    |  | (NSPasteboard)   |
|  +------------------+  +------------------+
+-----------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Menu Bar App | Status display, quick access, settings entry | `NSStatusItem` + `NSMenu` (not popover) |
| Floating Overlay | Recording state indicator, waveform display | `NSPanel` with `.floating` level |
| Settings Panel | Hotkey config, model selection, preferences | SwiftUI Window |
| Hotkey Manager | Capture global keyboard events | `CGEvent.tapCreate()` or KeyboardShortcuts library |
| Recording Manager | Microphone access, audio capture, buffering | `AVAudioEngine` with tap on input node |
| State Manager | App state, recording state, UI coordination | SwiftUI `@Observable` or Combine |
| Transcription Engine | ML inference, audio-to-text conversion | WhisperKit or whisper.cpp via SwiftWhisper |
| Text Insertion | Insert transcribed text into focused field | `AXUIElement` API + fallback to clipboard paste |

## Recommended Project Structure

```
VoiceType/
├── App/
│   ├── VoiceTypeApp.swift          # @main entry, app lifecycle
│   ├── AppDelegate.swift           # NSApplicationDelegate for AppKit integration
│   └── AppState.swift              # Global observable state
├── UI/
│   ├── MenuBar/
│   │   ├── MenuBarController.swift # NSStatusItem management
│   │   └── StatusItemView.swift    # Menu content
│   ├── Overlay/
│   │   ├── FloatingPanel.swift     # NSPanel subclass
│   │   └── RecordingIndicator.swift# SwiftUI recording UI
│   └── Settings/
│       ├── SettingsView.swift      # Main settings window
│       ├── HotkeySection.swift     # Hotkey configuration
│       └── ModelSection.swift      # Model selection/download
├── Core/
│   ├── Hotkey/
│   │   ├── HotkeyManager.swift     # Global hotkey capture
│   │   └── HotkeyRecorder.swift    # Custom hotkey recording
│   ├── Recording/
│   │   ├── AudioRecorder.swift     # AVAudioEngine wrapper
│   │   └── AudioBuffer.swift       # Audio data management
│   ├── Transcription/
│   │   ├── TranscriptionEngine.swift  # Protocol/interface
│   │   ├── WhisperKitEngine.swift     # WhisperKit implementation
│   │   └── ModelManager.swift         # Model download/selection
│   └── TextInsertion/
│       ├── TextInsertionService.swift # Coordinate insertion strategies
│       ├── AccessibilityInsertion.swift # AXUIElement approach
│       └── ClipboardInsertion.swift   # Fallback clipboard paste
├── Utilities/
│   ├── Permissions.swift           # Permission checking/requesting
│   └── Extensions/                 # Swift extensions
├── Resources/
│   ├── Assets.xcassets             # App icons, images
│   └── Models/                     # Bundled Whisper models (optional)
└── Info.plist                      # App configuration, entitlements
```

### Structure Rationale

- **App/:** Application lifecycle separate from features. AppDelegate needed for hybrid SwiftUI/AppKit approach.
- **UI/:** Separation by UI component type. Menu bar and overlay require AppKit; settings can be pure SwiftUI.
- **Core/:** Business logic independent of UI. Each subsystem (hotkey, recording, transcription, insertion) is isolated.
- **Utilities/:** Shared infrastructure including permission handling which crosses multiple subsystems.

## Architectural Patterns

### Pattern 1: Hybrid SwiftUI/AppKit

**What:** Use SwiftUI for views and state management, AppKit for system integration.
**When to use:** Menu bar apps requiring deep macOS integration.
**Trade-offs:** More complex than pure SwiftUI, but necessary for global hotkeys, floating panels, and accessibility APIs.

**Example:**
```swift
@main
struct VoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("VoiceType", systemImage: appState.isRecording ? "mic.fill" : "mic") {
            MenuBarView()
                .environmentObject(appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanel: FloatingPanel?
    var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup global hotkeys (requires AppKit)
        hotkeyManager = HotkeyManager()

        // Setup floating panel (requires NSPanel)
        floatingPanel = FloatingPanel()
    }
}
```

### Pattern 2: Protocol-Based Engine Abstraction

**What:** Abstract transcription engine behind a protocol for flexibility.
**When to use:** When multiple implementations are possible (WhisperKit vs whisper.cpp vs Apple Speech).
**Trade-offs:** Slight indirection, but enables testing and future flexibility.

**Example:**
```swift
protocol TranscriptionEngine {
    func transcribe(audioData: Data) async throws -> TranscriptionResult
    func loadModel(_ model: WhisperModel) async throws
    var isReady: Bool { get }
}

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval
}

// Concrete implementation
class WhisperKitEngine: TranscriptionEngine {
    private var whisperKit: WhisperKit?

    func transcribe(audioData: Data) async throws -> TranscriptionResult {
        guard let kit = whisperKit else { throw TranscriptionError.notReady }
        let result = try await kit.transcribe(audioFrames: audioData.to16kHzPCM())
        return TranscriptionResult(
            text: result.map(\.text).joined(),
            segments: result.map { /* convert */ },
            processingTime: /* measure */
        )
    }
}
```

### Pattern 3: Fallback Chain for Text Insertion

**What:** Try accessibility API first, fall back to clipboard paste if that fails.
**When to use:** Text insertion across arbitrary applications.
**Trade-offs:** Accessibility API is preferred but not always available; clipboard modifies user's clipboard.

**Example:**
```swift
class TextInsertionService {
    private let accessibilityInsertion = AccessibilityInsertion()
    private let clipboardInsertion = ClipboardInsertion()

    func insert(text: String) async -> InsertionResult {
        // Try accessibility first
        if let result = try? await accessibilityInsertion.insert(text) {
            return result
        }

        // Fall back to clipboard paste simulation
        return await clipboardInsertion.insert(text)
    }
}

class AccessibilityInsertion {
    func insert(text: String) async throws {
        guard AXIsProcessTrusted() else {
            throw InsertionError.accessibilityNotGranted
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard let element = focusedElement else {
            throw InsertionError.noFocusedElement
        }

        // Set value or insert at selection
        AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, text as CFString)
    }
}
```

## Data Flow

### Recording-to-Text Flow

```
┌─────────────┐
│ Hotkey Down │
└──────┬──────┘
       │ (CGEvent callback)
       v
┌─────────────────┐     ┌──────────────────┐
│ Start Recording │────>│ Show Floating    │
│ (AudioRecorder) │     │ Indicator        │
└────────┬────────┘     └──────────────────┘
         │
         │ (AVAudioEngine tap)
         v
┌─────────────────┐
│ Buffer Audio    │ (accumulate PCM data)
│ 16kHz mono      │
└────────┬────────┘
         │
┌────────┴────────┐
│ Hotkey Up       │
└────────┬────────┘
         │
         v
┌─────────────────┐     ┌──────────────────┐
│ Stop Recording  │────>│ Update Indicator │
│                 │     │ "Processing..."  │
└────────┬────────┘     └──────────────────┘
         │
         │ (async)
         v
┌─────────────────┐
│ Whisper Infer   │ (Metal/ANE acceleration)
│ ~0.5-2s         │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Text Result     │
└────────┬────────┘
         │
         v
┌─────────────────┐     ┌──────────────────┐
│ Insert Text     │────>│ Hide Indicator   │
│ (Accessibility) │     │                  │
└─────────────────┘     └──────────────────┘
```

### State Management

```
                    ┌─────────────────────────────────┐
                    │           AppState               │
                    │  ─────────────────────────────  │
                    │  @Published isRecording: Bool    │
                    │  @Published recordingDuration    │
                    │  @Published isProcessing: Bool   │
                    │  @Published lastTranscription    │
                    │  @Published selectedModel        │
                    │  @Published hotkey: KeyCombo     │
                    └───────────────┬─────────────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
            v                       v                       v
    ┌───────────────┐      ┌───────────────┐      ┌───────────────┐
    │  MenuBarView  │      │FloatingPanel  │      │ SettingsView  │
    │  (observes)   │      │  (observes)   │      │  (observes)   │
    └───────────────┘      └───────────────┘      └───────────────┘
```

### Key Data Flows

1. **Hotkey Activation:** CGEventTap catches keyDown -> HotkeyManager -> AppState.isRecording = true
2. **Audio Recording:** AVAudioEngine tap -> buffer accumulation -> Data ready on hotkey release
3. **Transcription:** Audio data -> WhisperKit/whisper.cpp -> TranscriptionResult
4. **Text Insertion:** TranscriptionResult.text -> AXUIElement focused element -> set value

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single user | Current architecture is sufficient |
| Power user (many transcriptions) | Consider caching/history, model preloading |
| Enterprise (fleet deployment) | MDM configuration, centralized model distribution |

### Performance Priorities

1. **First bottleneck:** Model loading time on first use. Preload model at app launch.
2. **Second bottleneck:** Transcription latency. Use Metal/ANE acceleration, appropriate model size.

## Anti-Patterns

### Anti-Pattern 1: Using NSPopover for Menu Bar

**What people do:** Use NSPopover for menu bar UI because tutorials show it.
**Why it's wrong:** Feels sluggish, doesn't dismiss naturally, behaves like "floating app" not system utility.
**Do this instead:** Use NSMenu for instant open, native animations, standard dismiss behavior.

### Anti-Pattern 2: Sandboxed App Store Distribution

**What people do:** Try to distribute via Mac App Store with sandboxing.
**Why it's wrong:** Accessibility API for text insertion and CGEventTap for global hotkeys are incompatible with sandbox.
**Do this instead:** Distribute via Developer ID with notarization. Non-sandboxed apps can use all required APIs.

### Anti-Pattern 3: Synchronous Transcription

**What people do:** Block main thread waiting for transcription.
**Why it's wrong:** UI freezes, poor user experience.
**Do this instead:** Use async/await, show "processing" indicator, keep UI responsive.

### Anti-Pattern 4: Single Text Insertion Strategy

**What people do:** Only use accessibility API OR only use clipboard.
**Why it's wrong:** Accessibility API may not work in all apps; clipboard-only modifies user data.
**Do this instead:** Fallback chain: try accessibility first, fall back to clipboard paste simulation.

## Integration Points

### External Libraries

| Library | Integration Pattern | Notes |
|---------|---------------------|-------|
| WhisperKit | Swift Package Manager | Recommended for Apple Silicon optimization |
| whisper.cpp (SwiftWhisper) | Swift Package Manager | Alternative, more control |
| KeyboardShortcuts | Swift Package Manager | Simplifies hotkey recording UI |
| LaunchAtLogin | Swift Package Manager | System integration for startup |
| Sparkle | Swift Package Manager | Auto-updates outside App Store |

### System APIs

| API | Purpose | Permission Required |
|-----|---------|---------------------|
| AVAudioEngine | Audio recording | Microphone (NSMicrophoneUsageDescription) |
| CGEvent.tapCreate | Global hotkey capture | Input Monitoring (Privacy_ListenEvent) |
| AXUIElement | Text insertion | Accessibility (Privacy_Accessibility) |
| NSPasteboard | Clipboard fallback | None |
| NSStatusItem | Menu bar presence | None |
| NSPanel | Floating indicator | None |

### Permission Flow

```
App Launch
    │
    v
┌───────────────────────────────────────┐
│ Check Microphone Permission           │
│ AVCaptureDevice.requestAccess(for: .audio)
└───────────────────────────────────────┘
    │
    v
┌───────────────────────────────────────┐
│ Check Accessibility Permission        │
│ AXIsProcessTrusted()                  │
│ If false: Open System Preferences     │
└───────────────────────────────────────┘
    │
    v
┌───────────────────────────────────────┐
│ Check Input Monitoring Permission     │
│ CGPreflightListenEventAccess()        │
│ If false: CGRequestListenEventAccess()│
└───────────────────────────────────────┘
    │
    v
┌───────────────────────────────────────┐
│ App Ready                             │
│ All permissions granted               │
└───────────────────────────────────────┘
```

## macOS-Specific Considerations

### Entitlements Required

```xml
<!-- Entitlements.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Microphone access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- NOT sandboxed - required for accessibility and global hotkeys -->
    <!-- com.apple.security.app-sandbox is deliberately absent -->

    <!-- Hardened runtime exceptions if needed -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

### Info.plist Keys

```xml
<!-- Usage descriptions -->
<key>NSMicrophoneUsageDescription</key>
<string>VoiceType needs microphone access to transcribe your speech.</string>

<!-- Hide dock icon (menu bar only) -->
<key>LSUIElement</key>
<true/>

<!-- Minimum macOS version -->
<key>LSMinimumSystemVersion</key>
<string>14.0</string>
```

### Distribution Strategy

| Method | Sandbox | Pros | Cons |
|--------|---------|------|------|
| Mac App Store | Required | Discovery, trust | Cannot use accessibility API, CGEventTap |
| Developer ID + Notarization | Optional | Full API access | Less discovery, user must allow |
| Direct Distribution | None | Full control | Gatekeeper warnings |

**Recommendation:** Developer ID with notarization. Non-sandboxed apps can use all required APIs while still providing security assurance to users.

## Build Order Implications

Based on component dependencies, suggested build order:

1. **Phase 1: Foundation**
   - App shell (menu bar presence)
   - Permissions handling
   - Basic state management

2. **Phase 2: Audio Pipeline**
   - AVAudioEngine setup
   - Recording start/stop
   - Audio buffering

3. **Phase 3: Transcription**
   - WhisperKit integration
   - Model management
   - Vietnamese model testing

4. **Phase 4: System Integration**
   - Global hotkey capture
   - Text insertion (accessibility + clipboard fallback)
   - Floating indicator

5. **Phase 5: Polish**
   - Settings UI
   - Model selection
   - Auto-update (Sparkle)

**Rationale:**
- Permissions and app shell are foundational
- Audio before transcription (can't transcribe without audio)
- Transcription before text insertion (can test transcription manually)
- Hotkeys and insertion together (both require similar permissions)
- Polish last (core functionality first)

## Sources

### Context7/Official Documentation
- [Apple Developer: AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement)
- [Apple Developer: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Apple Developer: Microphone Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.microphone)

### Libraries (GitHub)
- [WhisperKit - Argmax](https://github.com/argmaxinc/WhisperKit)
- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper)
- [KeyboardShortcuts - sindresorhus](https://github.com/sindresorhus/KeyboardShortcuts)
- [CGEventSupervisor](https://github.com/stephancasas/CGEventSupervisor)
- [AXorcist](https://github.com/steipete/AXorcist)
- [VoiceInk - Reference Implementation](https://github.com/Beingpax/VoiceInk)

### Community Resources
- [Building a MacOS Menu Bar App with Swift](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift-d6e293cd48eb)
- [Floating Window in SwiftUI macOS 15](https://www.polpiella.dev/creating-a-floating-window-using-swiftui-in-macos-15)
- [Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [Turbocharging transcription on Mac mini M4](https://itblog.today/blog/building/whisper-metal.html)

---
*Architecture research for: VoiceType macOS Speech-to-Text App*
*Researched: 2026-01-17*
