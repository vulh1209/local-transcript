# Phase 4: Polish - Research

**Researched:** 2026-01-18
**Domain:** SwiftUI Settings UI, WhisperKit Model Management, SwiftData Persistence
**Confidence:** HIGH

## Summary

Phase 4 requires implementing settings UI for model selection and language modes, status feedback for blocking operations, and transcription history storage. The research covers WhisperKit's model management APIs, SwiftData for history persistence, and SwiftUI patterns for toast/status feedback in menu bar apps.

Key findings:
- WhisperKit provides `fetchAvailableModels()` and download progress callbacks for model management
- Language mode is controlled via `DecodingOptions.language` parameter (nil for auto-detect, "vi" for Vietnamese, "en" for English)
- SwiftData is the modern approach for transcription history storage, with simple `@Model` macro
- The existing `FloatingIndicatorPanel` pattern can be extended for status feedback (downloading, transcribing, error states)
- KeyboardShortcuts library already supports multiple shortcuts with different names

**Primary recommendation:** Use existing architectural patterns (FloatingIndicatorPanel, KeyboardShortcuts, @Observable) and add SwiftData for history. Model switching requires unload/load cycle.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WhisperKit | Latest | Model management, transcription | Already integrated, provides model APIs |
| SwiftData | macOS 14+ | Transcription history storage | Apple's modern persistence framework |
| KeyboardShortcuts | 2.x | Language switch hotkey | Already integrated, supports multiple shortcuts |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AlertToast | 1.x | Toast notifications | If custom FloatingPanel insufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData | CoreData | CoreData is older, more boilerplate, but works on older macOS |
| SwiftData | JSON file | Simpler but no query capabilities, manual migration |
| AlertToast | Custom NSPanel | AlertToast has iOS/macOS support but less native feel |

**Installation:**
SwiftData is built into macOS 14+, no additional dependencies needed.

## Architecture Patterns

### Recommended Project Structure
```
LocalTranscript/
├── Services/
│   ├── ModelManager.swift        # Enhanced with model listing, download progress
│   └── HistoryManager.swift      # NEW: SwiftData container management
├── Models/
│   ├── AppState.swift            # Enhanced with language mode
│   ├── TranscriptionRecord.swift # NEW: SwiftData @Model
│   └── LanguageMode.swift        # NEW: Enum for language modes
├── Views/
│   ├── SettingsView.swift        # Enhanced with model picker, language picker
│   ├── HistoryView.swift         # NEW: List of past transcriptions
│   ├── StatusIndicatorPanel.swift # NEW: Enhanced floating panel for all states
│   └── ModelPickerView.swift     # NEW: Model selection with download status
```

### Pattern 1: WhisperKit Model Management
**What:** List available models, track download progress, switch models at runtime
**When to use:** Settings panel model selection
**Example:**
```swift
// Source: https://github.com/argmaxinc/WhisperKit
class ModelManager {
    // Available models for user selection (multilingual only)
    static let availableModels = [
        ("tiny", "Tiny (~40MB)", "Fastest, lower accuracy"),
        ("base", "Base (~75MB)", "Fast, decent accuracy"),
        ("small", "Small (~250MB)", "Balanced speed/accuracy"),
        ("medium", "Medium (~750MB)", "Better accuracy, slower"),
        ("large-v3", "Large (~1.5GB)", "Best accuracy, slowest")
    ]

    var downloadProgress: Double = 0
    var downloadStatus: String = ""

    func downloadModel(_ model: String) async throws {
        // WhisperKit download with progress callback
        let folder = try await WhisperKit.download(
            variant: model,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                    self.downloadStatus = "Downloading: \(Int(progress.fractionCompleted * 100))%"
                }
            }
        )
        // Then load the model
        self.modelFolder = folder
        try await loadModels()
    }

    func switchModel(to model: String) async throws {
        // Must unload before switching
        whisperKit?.unloadModels()
        whisperKit = nil
        // Re-initialize with new model
        whisperKit = try await WhisperKit(
            model: model,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true
        )
    }
}
```

### Pattern 2: Language Mode Configuration
**What:** Configure WhisperKit for specific language or auto-detect
**When to use:** Transcription with user-selected language mode
**Example:**
```swift
// Source: https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Configurations.swift
enum LanguageMode: String, CaseIterable {
    case auto = "Auto"
    case vietnamese = "Vietnamese"
    case english = "English"

    var whisperLanguageCode: String? {
        switch self {
        case .auto: return nil        // Auto-detect
        case .vietnamese: return "vi"
        case .english: return "en"
        }
    }
}

// In TranscriptionService
func transcribe(samples: [Float], languageMode: LanguageMode) async throws -> String {
    let options = DecodingOptions(
        task: .transcribe,
        language: languageMode.whisperLanguageCode,  // nil = auto-detect
        temperatureFallbackCount: 3,
        sampleLength: 224,
        usePrefillPrompt: true,
        usePrefillCache: true,
        skipSpecialTokens: true,
        withoutTimestamps: true
    )
    let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
    return results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
}
```

### Pattern 3: SwiftData Transcription History
**What:** Store and query transcription records
**When to use:** Persisting transcriptions for history view
**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftdata
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var text: String
    var timestamp: Date
    var languageMode: String  // Store as string for simplicity
    var duration: TimeInterval  // Recording duration in seconds

    init(text: String, languageMode: String, duration: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.languageMode = languageMode
        self.duration = duration
    }
}

// In App setup - use custom location to avoid conflicts
@main
struct LocalTranscriptApp: App {
    var body: some Scene {
        // ... existing scenes
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TranscriptionRecord.self])
        let config = ModelConfiguration(
            "LocalTranscript",
            schema: schema,
            url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LocalTranscript/history.store")
        )
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
```

### Pattern 4: Status Indicator Panel (Extended)
**What:** Floating panel showing different states (downloading, transcribing, error)
**When to use:** Visual feedback for blocking operations
**Example:**
```swift
// Source: Existing FloatingIndicatorPanel pattern in codebase
enum StatusIndicatorState {
    case recording
    case transcribing
    case downloading(progress: Double)
    case error(message: String)
    case languageChanged(LanguageMode)
}

class StatusIndicatorPanel: NSPanel {
    private var stateLabel: NSTextField!
    private var progressBar: NSProgressIndicator?

    func updateState(_ state: StatusIndicatorState) {
        switch state {
        case .recording:
            setContent(icon: "circle.fill", color: .systemRed, text: "Recording")
        case .transcribing:
            setContent(icon: "waveform", color: .systemBlue, text: "Transcribing...")
        case .downloading(let progress):
            setContent(icon: "arrow.down.circle", color: .systemOrange,
                      text: "Downloading: \(Int(progress * 100))%")
            showProgressBar(progress)
        case .error(let message):
            setContent(icon: "exclamationmark.triangle", color: .systemRed, text: message)
            // Auto-hide after 3 seconds
        case .languageChanged(let mode):
            setContent(icon: "globe", color: .systemGreen, text: mode.rawValue)
            // Auto-hide after 1.5 seconds
        }
    }
}
```

### Pattern 5: Language Switch Hotkey
**What:** Register second hotkey for cycling language modes
**When to use:** Quick language switching without opening settings
**Example:**
```swift
// Source: https://github.com/sindresorhus/KeyboardShortcuts
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
    static let cycleLanguage = Self("cycleLanguage", default: .init(.l, modifiers: [.option]))
}

// In AppState or HotkeyService
func setupLanguageHotkey() {
    KeyboardShortcuts.onKeyUp(for: .cycleLanguage) { [weak self] in
        self?.cycleLanguageMode()
        // Show brief indicator
        self?.showLanguageIndicator()
    }
}

func cycleLanguageMode() {
    let modes = LanguageMode.allCases
    if let currentIndex = modes.firstIndex(of: currentLanguageMode) {
        let nextIndex = (currentIndex + 1) % modes.count
        currentLanguageMode = modes[nextIndex]
    }
}
```

### Anti-Patterns to Avoid
- **Hot-swapping WhisperKit models:** Cannot change model without unload/reload cycle. Always unload first.
- **Storing history in @AppStorage:** AppStorage is for simple preferences, not structured data. Use SwiftData.
- **Using SwiftUI alerts for status:** Menu bar apps have limited window context. Use floating NSPanel instead.
- **Blocking UI during model download:** Always show progress and allow cancellation.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Model download progress | Custom URLSession download | WhisperKit.download(progressCallback:) | Handles HuggingFace auth, resume, validation |
| Keyboard shortcut UI | Custom key capture | KeyboardShortcuts.Recorder | Handles conflicts, system shortcuts, persistence |
| Transcription persistence | JSON file manager | SwiftData @Model | Query, migration, relationships built-in |
| Toast notifications | Custom animation code | NSPanel with auto-dismiss | Simpler, more reliable on macOS |

**Key insight:** WhisperKit handles all the complexity of model management (fetching available models, downloading, caching). Don't try to manually manage CoreML model files.

## Common Pitfalls

### Pitfall 1: Model Download Location Conflicts
**What goes wrong:** Using default WhisperKit download location conflicts with other apps
**Why it happens:** WhisperKit defaults to ~/Library/Caches which is shared
**How to avoid:** Specify custom downloadBase in WhisperKitConfig
**Warning signs:** Model loading fails after installing another WhisperKit app

### Pitfall 2: SwiftData Default Store Location
**What goes wrong:** Multiple apps using SwiftData with default.store overwrite each other
**Why it happens:** SwiftData defaults to ~/Library/Application Support/default.store
**How to avoid:** Always specify custom ModelConfiguration with app-specific path
**Warning signs:** Data disappears or crashes with schema mismatch

### Pitfall 3: Blocking Main Thread During Model Operations
**What goes wrong:** UI freezes during model download or loading
**Why it happens:** Model operations are slow and accidentally run on main thread
**How to avoid:** Always use async/await, show progress indicator
**Warning signs:** Spinning beach ball, unresponsive UI

### Pitfall 4: Menu Bar App Window Context Issues
**What goes wrong:** Alerts, sheets, popovers don't appear or appear behind other windows
**Why it happens:** Menu bar apps run as accessory (no dock icon), limited window management
**How to avoid:** Use NSPanel with .floating level, not SwiftUI alerts
**Warning signs:** Alert code runs but nothing visible

### Pitfall 5: Language Mode Not Persisting
**What goes wrong:** Language selection resets on app restart
**Why it happens:** Forgot to use @AppStorage or UserDefaults
**How to avoid:** Store language mode in @AppStorage("languageMode")
**Warning signs:** User has to re-select language every launch

## Code Examples

Verified patterns from official sources:

### Settings View with Model Picker
```swift
// Source: Existing SettingsView pattern + WhisperKit docs
struct SettingsView: View {
    @Environment(AppState.self) var appState
    @AppStorage("selectedModel") private var selectedModel = "small"
    @AppStorage("languageMode") private var languageMode = LanguageMode.auto.rawValue

    var body: some View {
        Form {
            Section("Model") {
                Picker("Whisper Model", selection: $selectedModel) {
                    ForEach(ModelManager.availableModels, id: \.0) { model in
                        HStack {
                            Text(model.1)  // Display name
                            Spacer()
                            Text(model.2)  // Description
                                .foregroundStyle(.secondary)
                        }
                        .tag(model.0)
                    }
                }
                .onChange(of: selectedModel) { _, newValue in
                    Task {
                        try? await appState.modelManager.switchModel(to: newValue)
                    }
                }

                // Download status
                if appState.modelManager.isDownloading {
                    ProgressView(value: appState.modelManager.downloadProgress)
                    Text(appState.modelManager.downloadStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Language") {
                Picker("Language Mode", selection: $languageMode) {
                    ForEach(LanguageMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                KeyboardShortcuts.Recorder("Cycle Language:", name: .cycleLanguage)
            }
        }
    }
}
```

### History View with SwiftData Query
```swift
// Source: https://developer.apple.com/documentation/swiftdata
import SwiftData

struct HistoryView: View {
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse)
    private var records: [TranscriptionRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.text)
                        .lineLimit(2)
                    HStack {
                        Text(record.timestamp, style: .relative)
                        Text("•")
                        Text(record.languageMode)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.text, forType: .string)
                    }
                    Button("Delete", role: .destructive) {
                        modelContext.delete(record)
                    }
                }
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CoreData for persistence | SwiftData with @Model | WWDC 2023 | Less boilerplate, Swift-native |
| Manual model downloads | WhisperKit.download() with progress | WhisperKit 0.5+ | Built-in HuggingFace support |
| NSStatusItem for menu bar | MenuBarExtra in SwiftUI | macOS 13+ | Declarative, easier state management |

**Deprecated/outdated:**
- Manual URLSession model downloads: Use WhisperKit's built-in download with progress
- UserDefaults for structured data: Use SwiftData for history, keep UserDefaults for simple prefs

## Open Questions

Things that couldn't be fully resolved:

1. **Model size validation before download**
   - What we know: WhisperKit downloads models automatically
   - What's unclear: How to check available disk space before download, how to cancel mid-download
   - Recommendation: Show estimated size in UI, handle download errors gracefully

2. **History retention policy**
   - What we know: SwiftData can store unlimited records
   - What's unclear: What's reasonable limit? Should old records auto-delete?
   - Recommendation: Start with last 100 records, add "Clear History" button

3. **Model preloading strategy**
   - What we know: Can prewarm models, lazy loading works
   - What's unclear: Should we preload on app launch if user frequently uses?
   - Recommendation: Keep lazy loading, consider background preload option in future

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub README](https://github.com/argmaxinc/WhisperKit) - Model management, download APIs
- [WhisperKit Configurations.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Configurations.swift) - DecodingOptions, language codes
- [HuggingFace argmaxinc/whisperkit-coreml](https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main) - Available model variants
- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata) - @Model, ModelContainer, @Query
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) - Multiple shortcut registration

### Secondary (MEDIUM confidence)
- [SwiftData Storage on Mac](https://gist.github.com/pdarcey/981b99bcc436a64df222cd8e3dd92871) - Custom storage location
- [Floating Panel Tutorial](https://cindori.com/developer/floating-panel) - NSPanel for status indicators
- [AlertToast Library](https://github.com/elai950/AlertToast) - Alternative toast approach

### Tertiary (LOW confidence)
- WebSearch results for SwiftUI toast patterns - Various approaches, not officially verified

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - WhisperKit, SwiftData, KeyboardShortcuts are well-documented
- Architecture: HIGH - Patterns derived from existing codebase and official docs
- Pitfalls: MEDIUM - Some based on general macOS app development experience

**Research date:** 2026-01-18
**Valid until:** 2026-02-18 (30 days - stable technologies)
