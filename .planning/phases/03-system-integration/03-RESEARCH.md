# Phase 03: System Integration - Research

**Researched:** 2026-01-17
**Domain:** Global hotkeys (CGEventTap/Carbon), text insertion (Accessibility API/CGEventPost), hold-to-talk modes
**Confidence:** HIGH

## Summary

This phase implements system-wide integration: global hotkeys that work from any app, hold-to-talk and toggle recording modes, and text insertion at the cursor position. The stack is well-established: **KeyboardShortcuts** (Sindre Sorhus) for user-configurable global hotkeys with SwiftUI UI, **CGEventPost** for simulating Cmd+V paste, and **Accessibility API** (AXUIElement) for direct text insertion with clipboard paste as fallback.

The primary technical challenges are:
1. Global hotkey detection with key-down/key-up for hold-to-talk mode
2. Text insertion across different app types (native, Electron, custom text fields)
3. Permission handling for Accessibility access (already prepared in Phase 1)

**Primary recommendation:** Use KeyboardShortcuts library for hotkey management (handles UserDefaults storage, conflict detection, SwiftUI recorder UI), with separate handlers for keyDown (start recording) and keyUp (stop recording) to enable hold-to-talk. For text insertion, use clipboard + CGEventPost Cmd+V as primary method (most compatible), with Accessibility API direct insertion as optimization for known-good apps.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| KeyboardShortcuts | latest | Global hotkey registration + UI | SwiftUI recorder, UserDefaults storage, conflict detection, sandbox compatible |
| CGEventPost | System | Keyboard event simulation | System API for Cmd+V paste simulation |
| AXUIElement | System | Text field access | Accessibility API for direct text insertion |
| NSPasteboard | System | Clipboard management | Standard pasteboard API |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| HotKey (soffes) | 0.2.1 | Simpler global hotkeys | If only hard-coded shortcuts needed |
| Carbon (HIToolbox) | System | Virtual key codes | Reference for CGKeyCode constants |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| KeyboardShortcuts | HotKey | HotKey simpler but no UI recorder, no UserDefaults storage |
| KeyboardShortcuts | CGEventTap directly | More control but complex Swift bridging, manual filtering |
| CGEventPost | AppleScript keystroke | More compatible but slower, requires Script permissions |
| Accessibility API | Direct typing simulation | AX is more reliable than character-by-character typing |

**Installation:**
```bash
# Swift Package Manager
# KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts
```

## Architecture Patterns

### Recommended Project Structure
```
LocalTranscript/
├── Services/
│   ├── HotkeyService.swift       # KeyboardShortcuts wrapper, mode management
│   ├── TextInsertionService.swift # Text insertion orchestration
│   └── TranscriptionService.swift # Existing - add text output callback
├── Models/
│   ├── AppState.swift            # Add hotkey mode, selected shortcut
│   └── RecordingMode.swift       # Hold-to-talk vs toggle enum
├── Views/
│   ├── SettingsView.swift        # Add hotkey recorder, mode selector
│   └── MenuBarView.swift         # Already exists
├── Utilities/
│   ├── KeyboardSimulator.swift   # CGEventPost wrapper
│   └── AccessibilityHelper.swift # AXUIElement wrapper
```

### Pattern 1: KeyboardShortcuts Integration
**What:** Register hotkey names, set up key-down/key-up handlers
**When to use:** App initialization
**Example:**
```swift
// Source: KeyboardShortcuts GitHub README
import KeyboardShortcuts

// 1. Register shortcut names
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}

// 2. Set up handlers in AppState init
@MainActor
@Observable
final class AppState {
    init() {
        setupHotkeyHandlers()
    }

    private func setupHotkeyHandlers() {
        // For toggle mode
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { await self?.transcriptionService.toggleRecording() }
        }
    }
}
```

### Pattern 2: Hold-to-Talk with KeyDown/KeyUp
**What:** Start on keyDown, stop on keyUp for push-to-talk
**When to use:** Hold-to-talk mode selected
**Example:**
```swift
// Source: KeyboardShortcuts documentation
@Observable
class HotkeyService {
    enum RecordingMode {
        case holdToTalk
        case toggle
    }

    var mode: RecordingMode = .holdToTalk
    private var onStartRecording: (() async -> Void)?
    private var onStopRecording: (() async -> Void)?

    func configure(onStart: @escaping () async -> Void, onStop: @escaping () async -> Void) {
        onStartRecording = onStart
        onStopRecording = onStop
        setupHandlers()
    }

    private func setupHandlers() {
        switch mode {
        case .holdToTalk:
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                Task { await self?.onStartRecording?() }
            }
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                Task { await self?.onStopRecording?() }
            }
        case .toggle:
            // Only respond to keyUp for toggle
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { }  // No-op
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                // Toggle logic handled by TranscriptionService
                Task { await self?.onStartRecording?() }
            }
        }
    }
}
```

### Pattern 3: Text Insertion via Clipboard + Cmd+V
**What:** Put text on clipboard, simulate Cmd+V paste
**When to use:** Primary text insertion method (most compatible)
**Example:**
```swift
// Source: Apple Developer Forums, clipboard manager patterns
import AppKit
import CoreGraphics

class TextInsertionService {
    private let pasteboard = NSPasteboard.general

    func insertText(_ text: String) {
        // 1. Save current clipboard content (optional - for restore)
        let previousContent = pasteboard.string(forType: .string)

        // 2. Put our text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V
        simulatePaste()

        // 4. Optionally restore previous clipboard after delay
        // (User may want to keep transcribed text on clipboard)
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        // Virtual key code 9 = 'V' key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        // Add Command modifier
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // Post events
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
```

### Pattern 4: Direct Text Insertion via Accessibility API
**What:** Set text directly on focused element (faster, no clipboard pollution)
**When to use:** For apps known to support AX text insertion
**Example:**
```swift
// Source: Apple Developer Forums, Hammerspoon patterns
import ApplicationServices

class AccessibilityHelper {
    /// Insert text at cursor using Accessibility API
    /// Returns true if successful, false if fallback needed
    func insertTextAtCursor(_ text: String) -> Bool {
        // Get focused element
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
        let element = focusedElement as! AXUIElement? else {
            return false
        }

        // Try to set selected text (inserts at cursor)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return result == .success
    }

    /// Check if element supports text insertion
    func canInsertText(in element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        )
        return result == .success && settable.boolValue
    }
}
```

### Pattern 5: SwiftUI Hotkey Recorder
**What:** User-configurable hotkey selection UI
**When to use:** Settings view
**Example:**
```swift
// Source: KeyboardShortcuts README
import SwiftUI
import KeyboardShortcuts

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            Section("Recording Hotkey") {
                KeyboardShortcuts.Recorder("Shortcut:", name: .toggleRecording)
                    .padding(.vertical, 4)

                Text("Press your preferred key combination")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Recording Mode") {
                Picker("Mode", selection: $recordingMode) {
                    Text("Hold to Talk").tag(RecordingMode.holdToTalk)
                    Text("Toggle").tag(RecordingMode.toggle)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
```

### Anti-Patterns to Avoid
- **Don't poll for key state:** Use event-driven handlers from KeyboardShortcuts
- **Don't assume Accessibility always works:** Electron apps have known issues; always have clipboard fallback
- **Don't restore clipboard immediately:** Give paste event time to complete (~100ms delay minimum)
- **Don't use AppleScript for speed-critical operations:** CGEventPost is faster
- **Don't register multiple handlers for same shortcut:** KeyboardShortcuts replaces handlers on re-registration

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hotkey detection | CGEventTap filtering | KeyboardShortcuts | Handles TCC, UserDefaults, conflict detection |
| Shortcut recorder UI | NSEvent monitoring | KeyboardShortcuts.Recorder | Native appearance, conflict warnings |
| Key combo persistence | Custom Codable | KeyboardShortcuts (auto) | Library handles UserDefaults automatically |
| Modifier key symbols | String formatting | KeyboardShortcuts (ks_symbolicRepresentation) | Correct symbols for all modifiers |
| Virtual key codes | Magic numbers | Carbon.HIToolbox constants | Named constants prevent errors |

**Key insight:** KeyboardShortcuts handles 90% of hotkey complexity (TCC permissions, UserDefaults, UI, conflict detection). Don't replicate this.

## Common Pitfalls

### Pitfall 1: Text Insertion Fails in Electron Apps
**What goes wrong:** Direct AX insertion doesn't work in VSCode, Slack, etc.
**Why it happens:** Electron apps have incomplete/buggy Accessibility support
**How to avoid:** Always use clipboard+Cmd+V as primary method; AX only as optimization
**Warning signs:** AXUIElementSetAttributeValue returns success but text doesn't appear

### Pitfall 2: Clipboard Content Lost
**What goes wrong:** User's clipboard content is replaced by transcription
**Why it happens:** Using pasteboard for text insertion
**How to avoid:** Either accept this (transcribed text stays on clipboard) or restore after delay
**Warning signs:** User complaints about lost clipboard content

### Pitfall 3: Paste Event Arrives Before Clipboard Update
**What goes wrong:** Pasting old content or nothing
**Why it happens:** CGEventPost is async, clipboard update may not complete
**How to avoid:** Use main thread for clipboard, small delay (~50ms) before paste event
**Warning signs:** Intermittent wrong text insertion

### Pitfall 4: Hotkey Conflicts with System Shortcuts
**What goes wrong:** User chooses Cmd+Space, nothing works
**Why it happens:** System shortcuts take priority
**How to avoid:** KeyboardShortcuts.Recorder warns about conflicts automatically
**Warning signs:** Shortcut works sometimes, not others

### Pitfall 5: Hold-to-Talk Triggers Multiple Times
**What goes wrong:** Recording starts repeatedly while holding key
**Why it happens:** Key repeat generates multiple keyDown events
**How to avoid:** Track recording state, ignore keyDown if already recording
**Warning signs:** Multiple "start recording" sounds, state confusion

### Pitfall 6: Accessibility Permission Not Granted
**What goes wrong:** CGEventPost doesn't work, no paste happens
**Why it happens:** Accessibility permission required for posting events to other apps
**How to avoid:** Check AXIsProcessTrusted() before attempting, prompt user
**Warning signs:** Permission dialog appears, or silent failure

## Code Examples

Verified patterns from official sources:

### Complete HotkeyService
```swift
// Source: Synthesized from KeyboardShortcuts docs, Shush app pattern
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
}

@Observable
class HotkeyService {
    enum RecordingMode: String, CaseIterable {
        case holdToTalk = "Hold to Talk"
        case toggle = "Toggle"
    }

    var mode: RecordingMode = .holdToTalk {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "recordingMode")
            rebindHandlers()
        }
    }

    private var isRecording = false
    private var onStart: (() async throws -> Void)?
    private var onStop: (() async -> Void)?

    init() {
        if let savedMode = UserDefaults.standard.string(forKey: "recordingMode"),
           let mode = RecordingMode(rawValue: savedMode) {
            self.mode = mode
        }
    }

    func bind(onStart: @escaping () async throws -> Void, onStop: @escaping () async -> Void) {
        self.onStart = onStart
        self.onStop = onStop
        rebindHandlers()
    }

    private func rebindHandlers() {
        // Clear existing handlers by setting empty closures
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { }
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { }

        switch mode {
        case .holdToTalk:
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                guard let self, !self.isRecording else { return }
                self.isRecording = true
                Task { try? await self.onStart?() }
            }
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                guard let self, self.isRecording else { return }
                self.isRecording = false
                Task { await self.onStop?() }
            }

        case .toggle:
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                guard let self else { return }
                if self.isRecording {
                    self.isRecording = false
                    Task { await self.onStop?() }
                } else {
                    self.isRecording = true
                    Task { try? await self.onStart?() }
                }
            }
        }
    }
}
```

### Complete TextInsertionService
```swift
// Source: Synthesized from Apple Developer Forums, clipboard manager patterns
import AppKit
import CoreGraphics
import ApplicationServices

@Observable
class TextInsertionService {
    private let pasteboard = NSPasteboard.general

    enum InsertionError: Error {
        case accessibilityNotGranted
        case noFocusedElement
        case insertionFailed
    }

    /// Insert text at cursor position in any app
    /// Uses clipboard + Cmd+V as primary method
    @MainActor
    func insertText(_ text: String) async throws {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw InsertionError.accessibilityNotGranted
        }

        // Try direct Accessibility insertion first (faster, no clipboard pollution)
        if tryDirectInsertion(text) {
            return
        }

        // Fallback to clipboard + paste
        try await insertViaClipboard(text)
    }

    /// Try direct text insertion via Accessibility API
    private func tryDirectInsertion(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
        let element = focusedElement as! AXUIElement? else {
            return false
        }

        // Check if we can set text
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        ) == .success, settable.boolValue else {
            return false
        }

        // Insert text
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return result == .success
    }

    /// Insert text via clipboard and Cmd+V
    @MainActor
    private func insertViaClipboard(_ text: String) async throws {
        // Put text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        try await Task.sleep(for: .milliseconds(50))

        // Simulate Cmd+V
        simulatePaste()
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        // Virtual key code 9 = 'V' key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
```

### Settings View with Hotkey Recorder
```swift
// Source: KeyboardShortcuts README
import SwiftUI
import KeyboardShortcuts

struct HotkeySettingsSection: View {
    @Bindable var hotkeyService: HotkeyService

    var body: some View {
        Section("Hotkey") {
            KeyboardShortcuts.Recorder("Recording Shortcut:", name: .toggleRecording)

            Picker("Mode", selection: $hotkeyService.mode) {
                ForEach(HotkeyService.RecordingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(hotkeyDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hotkeyDescription: String {
        switch hotkeyService.mode {
        case .holdToTalk:
            return "Hold the shortcut to record, release to transcribe and insert"
        case .toggle:
            return "Press once to start recording, press again to stop and insert"
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Carbon RegisterEventHotKey | KeyboardShortcuts library | 2020+ | Modern Swift API, SwiftUI support |
| Manual key combo storage | KeyboardShortcuts auto-storage | 2020+ | Automatic UserDefaults handling |
| AppleScript keystroke | CGEventPost | macOS 10.4+ | Faster, more reliable |
| Character-by-character typing | Clipboard + Cmd+V | Always | Much faster for long text |
| AX-only text insertion | Clipboard with AX fallback | 2020+ | Better Electron compatibility |

**Deprecated/outdated:**
- RegisterEventHotKey direct usage: Use KeyboardShortcuts wrapper instead
- MASShortcut: Objective-C, less SwiftUI integration
- AppleScript for keyboard simulation: CGEventPost is faster and more reliable

## Open Questions

Things that couldn't be fully resolved:

1. **Electron App Text Insertion Edge Cases**
   - What we know: VSCode, Slack have AX bugs; clipboard+paste works
   - What's unclear: Full list of affected apps, whether some support partial AX
   - Recommendation: Always prefer clipboard method; track which apps fail

2. **Clipboard Restore After Insertion**
   - What we know: Users may want to keep transcribed text, or want original content
   - What's unclear: Which behavior users prefer
   - Recommendation: Start with keeping transcribed text on clipboard (more useful); add preference later if requested

3. **Optimal Delay Before Paste Event**
   - What we know: Need some delay for clipboard sync
   - What's unclear: Minimum reliable delay varies by system load
   - Recommendation: Start with 50ms; increase if reports of failures

## Sources

### Primary (HIGH confidence)
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) - API, SwiftUI integration, keyDown/keyUp handlers
- [Apple CGEventCreateKeyboardEvent](https://developer.apple.com/documentation/coregraphics/1456564-cgeventcreatekeyboardevent) - Keyboard simulation
- [Apple AXUIElementSetAttributeValue](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue) - Direct text insertion
- [Apple Developer Forums - Global Hotkeys](https://developer.apple.com/forums/thread/735223) - CGEventTap vs Carbon comparison

### Secondary (MEDIUM confidence)
- [HotKey GitHub](https://github.com/soffes/HotKey) - Alternative library, keyDown/keyUp API
- [Electron Accessibility Issues](https://github.com/electron/electron/issues/36337) - Known AX bugs
- [Swift Virtual KeyCode Reference](https://gist.github.com/swillits/df648e87016772c7f7e5dbed2b345066) - Key code constants

### Tertiary (LOW confidence)
- Clipboard restore timing - empirical testing needed
- Full list of Electron app AX limitations - requires testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - KeyboardShortcuts is well-maintained, widely used
- Architecture: HIGH - Patterns verified from multiple sources
- Text insertion: MEDIUM - AX edge cases in Electron apps need testing
- Pitfalls: HIGH - Common issues well-documented

**Research date:** 2026-01-17
**Valid until:** 2026-02-17 (30 days - stable domain)
