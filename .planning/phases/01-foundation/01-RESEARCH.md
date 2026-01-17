# Phase 1: Foundation - Research

**Researched:** 2026-01-17
**Domain:** macOS Menu Bar App Shell, Permissions, Model Loading
**Confidence:** HIGH (verified with official docs, GitHub repos, and recent tutorials)

## Summary

Phase 1 establishes the foundational architecture for a non-sandboxed macOS menu bar app capable of loading the PhoWhisper model. The key challenges are:

1. **SwiftUI MenuBarExtra** works well for the menu bar shell but has known issues with Settings windows
2. **Non-sandboxed distribution** is required for Accessibility API access (text insertion in Phase 3)
3. **Permission flows** for microphone and accessibility require careful UX design
4. **PhoWhisper model loading** via SwiftWhisper with GGML format is straightforward but has first-run CoreML compilation delays

**Primary recommendation:** Use SwiftUI MenuBarExtra with the hidden window workaround for Settings. Load PhoWhisper GGML model asynchronously at first use, not app launch. Use SMAppService directly for login items (no third-party library needed).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar app UI | Native Apple solution, declarative |
| SwiftWhisper | 1.2.0+ | Whisper model loading | Swift-native wrapper for whisper.cpp |
| SMAppService | macOS 13+ | Login item management | Native API, no helper app needed |
| AVCaptureDevice | Built-in | Microphone permission | Apple's authorization API |
| AXIsProcessTrusted | Built-in | Accessibility permission | Only way to check accessibility |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SettingsAccess | 2.1.0+ | Settings window workaround | If native openSettings fails |
| LaunchAtLogin | Latest | Login item convenience | If want SwiftUI Toggle binding |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftUI MenuBarExtra | NSStatusItem (AppKit) | More control, but more code; needed only for macOS 12 support |
| SMAppService | LaunchAtLogin package | Convenience vs. dependency; SMAppService is simple enough directly |
| SettingsAccess | Hidden window workaround | Both work; SettingsAccess is cleaner but adds dependency |

**Installation:**
```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "1.2.0"),
    // Optional: only if native Settings fails
    .package(url: "https://github.com/orchetect/SettingsAccess.git", from: "2.1.0"),
]
```

## Architecture Patterns

### Recommended Project Structure

```
LocalTranscript/
├── LocalTranscriptApp.swift      # @main, scene declarations
├── Views/
│   ├── MenuBarView.swift         # MenuBarExtra content
│   ├── SettingsView.swift        # Settings window content
│   └── HiddenWindowView.swift    # Settings activation workaround
├── Services/
│   ├── PermissionManager.swift   # Microphone + Accessibility
│   ├── ModelManager.swift        # PhoWhisper loading
│   └── LaunchManager.swift       # Login item via SMAppService
├── Models/
│   └── AppState.swift            # @Observable app state
├── Resources/
│   └── models/                   # GGML model files (or download location)
└── Supporting Files/
    ├── Info.plist                # Privacy descriptions, LSUIElement
    └── LocalTranscript.entitlements
```

### Pattern 1: Menu Bar App Declaration (LSUIElement)

**What:** Make app appear only in menu bar, not Dock
**When to use:** Always for menu bar utilities

```swift
// Info.plist
<key>LSUIElement</key>
<true/>

// Or via Xcode: Target > Info > Application is agent (UIElement) = YES
```

### Pattern 2: MenuBarExtra with Window Style

**What:** Use `.window` style for custom UI beyond simple menus
**When to use:** When Settings button needs custom activation handling

```swift
// Source: Apple Developer Documentation + nilcoalescing.com
@main
struct LocalTranscriptApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        // Hidden window MUST come before Settings scene
        Window("Hidden", id: "HiddenWindow") {
            HiddenWindowView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        MenuBarExtra("LocalTranscript", systemImage: "waveform") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.menu) // or .window for custom UI

        Settings {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    NotificationCenter.default.post(
                        name: .settingsWindowClosed,
                        object: nil
                    )
                }
        }
    }
}
```

### Pattern 3: Settings Window Activation Workaround

**What:** Hidden window that receives openSettings environment and handles activation
**When to use:** Always for menu bar apps with Settings

```swift
// Source: steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    // Temporarily show dock icon so Settings can receive focus
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))

                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()

                    try? await Task.sleep(for: .milliseconds(200))
                    if let window = NSApp.windows.first(where: {
                        $0.identifier?.rawValue == "com.apple.SwiftUI.Settings" ||
                        $0.title.localizedCaseInsensitiveContains("settings")
                    }) {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                // Hide dock icon again
                NSApp.setActivationPolicy(.accessory)
            }
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
    static let settingsWindowClosed = Notification.Name("settingsWindowClosed")
}
```

### Pattern 4: SMAppService Login Item

**What:** Native API for "start at login" without helper apps
**When to use:** macOS 13+ (our minimum target)

```swift
// Source: nilcoalescing.com/blog/LaunchAtLoginSetting/
import ServiceManagement

@Observable
class AppState {
    var launchAtLogin: Bool = false {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    func syncLaunchAtLoginStatus() {
        // Always read from system, user may have changed in System Settings
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// In SettingsView
Toggle("Start at Login", isOn: $appState.launchAtLogin)
    .onAppear {
        appState.syncLaunchAtLoginStatus()
    }
```

### Pattern 5: Microphone Permission Request

**What:** Request and handle microphone authorization
**When to use:** Before any audio capture attempt

```swift
// Source: Apple Developer Documentation + developer forums
import AVFoundation

class PermissionManager {
    enum MicrophoneStatus {
        case authorized
        case denied
        case notDetermined
    }

    func checkMicrophonePermission() -> MicrophoneStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
```

### Pattern 6: Accessibility Permission Check

**What:** Check and guide user to enable accessibility permission
**When to use:** Before any CGEvent text insertion (Phase 3, but check in Phase 1)

```swift
// Source: jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html
import ApplicationServices

extension PermissionManager {
    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### Pattern 7: SwiftWhisper Model Loading (Async)

**What:** Load GGML model asynchronously, not blocking UI
**When to use:** First time user triggers recording, not at app launch

```swift
// Source: github.com/exPHAT/SwiftWhisper
import SwiftWhisper

@Observable
class ModelManager {
    private(set) var whisper: Whisper?
    private(set) var isLoading = false
    private(set) var loadError: Error?

    func loadModel() async throws {
        guard whisper == nil, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        // Option 1: Bundled model
        guard let modelURL = Bundle.main.url(
            forResource: "ggml-phowhisper-medium",
            withExtension: "bin"
        ) else {
            throw ModelError.modelNotFound
        }

        // Option 2: Downloaded model in Application Support
        // let modelURL = getModelStoragePath().appendingPathComponent("ggml-phowhisper-medium.bin")

        whisper = Whisper(fromFileURL: modelURL)
    }

    private func getModelStoragePath() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalTranscript")
    }

    enum ModelError: Error {
        case modelNotFound
    }
}
```

### Anti-Patterns to Avoid

- **Synchronous model loading at app launch:** Freezes UI for 3-5+ seconds. Always load async on first use.
- **Using SettingsLink directly in MenuBarExtra:** Doesn't work properly; use hidden window workaround.
- **Storing launchAtLogin in UserDefaults:** User can change in System Settings; always read from SMAppService.
- **Requesting Accessibility in sandboxed app:** Will never work. Must be non-sandboxed.
- **Scene order matters:** Hidden window must be declared BEFORE Settings scene.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Login item management | launchd plist manipulation | SMAppService | Apple's sanctioned API, handles edge cases |
| Settings window for menu bar | Manual NSWindow creation | Hidden window + openSettings | SwiftUI-native, less code |
| GGML model loading | Direct whisper.cpp C API | SwiftWhisper | Swift-idiomatic, handles threading |
| Microphone permission | Custom TCC database access | AVCaptureDevice.requestAccess | The only supported way |

**Key insight:** macOS permissions and window management have many edge cases. Apple's APIs handle these; custom solutions will miss edge cases.

## Common Pitfalls

### Pitfall 1: Settings Window Never Opens or Opens Behind

**What goes wrong:** SettingsLink/openSettings does nothing in menu bar app, or window appears behind other apps
**Why it happens:** Menu bar apps use `.accessory` activation policy; macOS doesn't focus windows properly
**How to avoid:**
1. Use hidden window workaround (Pattern 3 above)
2. Temporarily switch to `.regular` activation policy
3. Declare hidden window BEFORE Settings scene
**Warning signs:** Settings menu item does nothing, works in Xcode but not release

### Pitfall 2: Microphone Permission Dialog Never Appears

**What goes wrong:** No permission dialog, audio is just silence (zeros)
**Why it happens:** Debug/unsigned builds may not trigger TCC dialogs properly
**How to avoid:**
1. Sign with valid Developer ID even for testing
2. Use `AVCaptureDevice.requestAccess(for: .audio)` - don't try to avoid the system dialog
3. Add `NSMicrophoneUsageDescription` to Info.plist
**Warning signs:** `authorizationStatus` returns `.notDetermined` even after user action

### Pitfall 3: Accessibility Permission Cannot Be Granted

**What goes wrong:** `AXIsProcessTrusted()` always returns false
**Why it happens:** App is sandboxed (not allowed for Accessibility API)
**How to avoid:**
1. Ensure App Sandbox entitlement is NOT present
2. Use Developer ID signing, not Mac App Store
3. Guide user to manually enable in System Settings > Privacy & Security > Accessibility
**Warning signs:** Works in Xcode, fails in exported app

### Pitfall 4: First CoreML Run Takes 30+ Minutes (Medium Model)

**What goes wrong:** First transcription hangs or takes extremely long
**Why it happens:** ANECompilerService compiles CoreML model on first run; medium model is large
**How to avoid:**
1. **Option A (Recommended for MVP):** Don't use CoreML encoder initially; use CPU/GPU via whisper.cpp
2. **Option B:** Warn user about first-run delay, show progress
3. **Option C:** Use MLX framework instead (avoids ANE compilation entirely)
**Warning signs:** First run takes 30+ minutes, subsequent runs are fast

### Pitfall 5: Model Loading Freezes App

**What goes wrong:** App becomes unresponsive during model initialization
**Why it happens:** Model loading done on main thread
**How to avoid:**
1. Load model in background Task
2. Show loading indicator during initialization
3. Don't load at app launch; load on first recording trigger
**Warning signs:** UI unresponsive for 3-5 seconds at startup

## Code Examples

### Complete App Entry Point

```swift
// Source: Verified pattern from steipete.me + Apple docs
import SwiftUI

@main
struct LocalTranscriptApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        // Order matters: Hidden window MUST come first
        Window("Hidden", id: "HiddenWindow") {
            HiddenWindowView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: appState.isRecording ? "waveform.circle.fill" : "waveform")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
                }
        }
    }
}
```

### Complete MenuBarView

```swift
// Source: Composite from nilcoalescing.com + sarunw.com tutorials
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            // Status display
            if appState.modelManager.isLoading {
                Text("Loading model...")
                    .foregroundStyle(.secondary)
            } else if appState.modelManager.whisper != nil {
                Text("Ready")
                    .foregroundStyle(.secondary)
            } else {
                Text("Model not loaded")
                    .foregroundStyle(.red)
            }

            Divider()

            // Settings button
            Button("Settings...") {
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit button (required for menu bar apps!)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
```

### Complete Info.plist Keys

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Menu bar only, no dock icon -->
    <key>LSUIElement</key>
    <true/>

    <!-- Microphone permission description -->
    <key>NSMicrophoneUsageDescription</key>
    <string>LocalTranscript needs microphone access for speech-to-text transcription.</string>

    <!-- Accessibility usage (informational, not required for entitlement) -->
    <key>NSAppleEventsUsageDescription</key>
    <string>LocalTranscript needs accessibility access to insert transcribed text into other applications.</string>
</dict>
</plist>
```

### Complete Entitlements (Non-Sandboxed + Hardened Runtime)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Audio input for microphone capture -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- NOTE: NO App Sandbox entitlement - intentionally non-sandboxed -->
    <!-- NOTE: NO com.apple.security.accessibility - it doesn't exist! -->
    <!-- Accessibility is controlled via System Settings, not entitlements -->
</dict>
</plist>
```

### UserDefaults with @AppStorage

```swift
// Source: hackingwithswift.com + Apple Documentation
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState

    // Simple preferences via @AppStorage (backed by UserDefaults)
    @AppStorage("selectedModel") private var selectedModel = "medium"
    @AppStorage("showRecordingIndicator") private var showIndicator = true

    var body: some View {
        Form {
            Section("General") {
                @Bindable var appState = appState
                Toggle("Start at Login", isOn: $appState.launchAtLogin)
                    .onAppear {
                        appState.syncLaunchAtLoginStatus()
                    }

                Toggle("Show Recording Indicator", isOn: $showIndicator)
            }

            Section("Model") {
                Picker("Model Size", selection: $selectedModel) {
                    Text("Small (600MB, faster)").tag("small")
                    Text("Medium (1.5GB, more accurate)").tag("medium")
                }
            }

            Section("Permissions") {
                PermissionStatusRow(
                    title: "Microphone",
                    isGranted: appState.permissionManager.checkMicrophonePermission() == .authorized,
                    requestAction: {
                        Task {
                            await appState.permissionManager.requestMicrophonePermission()
                        }
                    }
                )

                PermissionStatusRow(
                    title: "Accessibility",
                    isGranted: appState.permissionManager.checkAccessibilityPermission(),
                    requestAction: {
                        appState.permissionManager.openAccessibilitySettings()
                    }
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SMLoginItemSetEnabled | SMAppService | macOS 13 (2022) | No helper app needed |
| NSApp.sendAction(showSettingsWindow:) | openSettings environment | macOS 14 (2023) | Breaking change for menu bar apps |
| AppKit NSStatusItem | SwiftUI MenuBarExtra | macOS 13 (2022) | Declarative, simpler |
| Manual CoreML model conversion | Pre-converted GGML + optional CoreML | 2024 | Easier setup |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled`: Still works but deprecated; use SMAppService
- `NSApp.sendAction(#selector(NSApplication.showSettingsWindow:), to: nil, from: nil)`: Removed in macOS 14
- `@NSApplicationDelegateAdaptor` for menu bar: Not needed with MenuBarExtra

## Open Questions

1. **CoreML vs CPU-only for PhoWhisper medium:**
   - What we know: CoreML can be 3x faster but has 30+ minute first-run compilation
   - What's unclear: Whether pre-compiled CoreML models exist for PhoWhisper
   - Recommendation: Start with CPU/GPU only (still fast on M1+), add CoreML later if needed

2. **Model bundling vs download:**
   - What we know: Medium model is ~1.5GB, large for app bundle
   - What's unclear: Best UX for model download on first launch
   - Recommendation: Bundle for MVP simplicity; add download option in Polish phase

3. **Settings window alternative (SettingsAccess):**
   - What we know: SettingsAccess library provides cleaner API
   - What's unclear: Whether native hidden window workaround is sufficient
   - Recommendation: Try native approach first; add SettingsAccess if issues arise

## Sources

### Primary (HIGH confidence)
- [Apple Developer: MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra) - Official SwiftUI MenuBarExtra documentation
- [Apple Developer: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) - Login item API
- [Apple Developer: Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime_entitlements) - Entitlements reference
- [GitHub: exPHAT/SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) - Official SwiftWhisper repository
- [GitHub: ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) - whisper.cpp with CoreML documentation

### Secondary (MEDIUM confidence)
- [Peter Steinberger: Showing Settings from Menu Bar Items](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) - Hidden window workaround (January 2025)
- [Nil Coalescing: Menu Bar Utility Tutorial](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) - Complete tutorial (February 2025)
- [Nil Coalescing: Launch at Login](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) - SMAppService implementation (January 2025)
- [jano.dev: Accessibility Permission](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) - AXIsProcessTrusted patterns (January 2025)
- [GitHub: orchetect/SettingsAccess](https://github.com/orchetect/SettingsAccess) - Alternative Settings solution

### Tertiary (LOW confidence - needs validation)
- [Sarunw: SwiftUI Menu Bar App](https://sarunw.com/posts/swiftui-menu-bar-app/) - Tutorial, verify patterns still work
- [HuggingFace: dongxiat/ggml-PhoWhisper-medium](https://huggingface.co/dongxiat/ggml-PhoWhisper-medium) - Pre-converted model availability

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries verified via GitHub repos and official docs
- Architecture patterns: HIGH - Verified with January/February 2025 tutorials
- Pitfalls: HIGH - Documented in Apple forums and community reports
- CoreML timing: MEDIUM - Reported in GitHub issues, varies by hardware

**Research date:** 2026-01-17
**Valid until:** 30 days (SwiftUI patterns stable, model loading patterns stable)
