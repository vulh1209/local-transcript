# Stack Research

**Domain:** macOS Vietnamese Speech-to-Text Application
**Researched:** 2026-01-17
**Confidence:** HIGH (verified with official docs and multiple sources)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Swift** | 5.9+ | Primary language | Native macOS development, best interop with Apple frameworks |
| **SwiftUI** | macOS 14+ | UI framework | Modern declarative UI, MenuBarExtra for menu bar apps |
| **whisper.cpp** | v1.8.3 | STT inference engine | 3-8x faster than Python Whisper on Apple Silicon with CoreML/Metal |
| **PhoWhisper-medium** | GGML format | Vietnamese ASR model | SOTA for Vietnamese: 4.97% WER on VIVOS, fine-tuned on 844h diverse accents |
| **AVAudioEngine** | Built-in | Audio capture | Native macOS microphone access, real-time audio stream |
| **CGEvent** | Built-in | Text insertion | System-wide keyboard event synthesis for text injection |

### Vietnamese Speech Recognition Model Selection

| Model | Parameters | VIVOS WER | CMV-Vi WER | RAM Usage | Recommendation |
|-------|------------|-----------|------------|-----------|----------------|
| PhoWhisper-tiny | 39M | 10.41% | 19.05% | ~200MB | Not recommended (poor accuracy) |
| PhoWhisper-base | 74M | 8.46% | 16.19% | ~300MB | Acceptable for constrained devices |
| **PhoWhisper-small** | 244M | **6.33%** | 11.08% | ~600MB | **Best balance for real-time** |
| **PhoWhisper-medium** | 769M | **4.97%** | 8.27% | ~1.5GB | **Recommended for accuracy focus** |
| PhoWhisper-large | 1.55B | 4.67% | 8.14% | ~3GB | Diminishing returns, slower inference |

**Recommendation:** Use **PhoWhisper-medium** (769M params, 4.97% WER on VIVOS). Given "accuracy > real-time display" requirement, the medium model provides the best tradeoff. On M1+ with CoreML, inference is fast enough for practical use.

**Source:** [VinAI PhoWhisper GitHub](https://github.com/VinAIResearch/PhoWhisper) - ICLR 2024 paper with benchmark tables.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **SwiftWhisper** | 1.2.0+ | Swift wrapper for whisper.cpp | Primary integration path - provides native Swift API, CoreML support |
| **KeyboardShortcuts** | Latest | Global hotkeys | User-configurable push-to-talk activation (Sindre Sorhus library) |
| **HotKey** | 0.2.1+ | Simple global shortcuts | Alternative if KeyboardShortcuts is overkill |

### macOS Frameworks (Built-in)

| Framework | Purpose | Notes |
|-----------|---------|-------|
| **AVFoundation** | Audio session management | Configure audio input, handle interruptions |
| **CoreML** | ML acceleration | 2-3x faster Whisper inference on Apple Neural Engine |
| **Metal** | GPU acceleration | Additional 3-4x speedup when combined with CoreML |
| **ApplicationServices** | CGEvent API | Required for text insertion into focused apps |
| **AppKit** | NSStatusItem, NSPanel | Menu bar icon, floating indicator window |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Xcode 15+** | IDE | Required for macOS 14+ SwiftUI features |
| **Swift Package Manager** | Dependencies | Native package management |
| **whisper.cpp convert-h5-to-ggml.py** | Model conversion | Convert HuggingFace PhoWhisper to GGML format |

## Architecture Decision: whisper.cpp vs WhisperKit

| Criterion | whisper.cpp + SwiftWhisper | WhisperKit |
|-----------|---------------------------|------------|
| **Vietnamese model support** | Yes (convert PhoWhisper) | No (standard Whisper only) |
| **macOS version** | macOS 13+ | macOS 14+ |
| **Model format** | GGML (custom) | CoreML |
| **Flexibility** | High (any fine-tuned model) | Low (predefined models) |
| **Setup complexity** | Medium (conversion needed) | Low (automatic download) |

**Recommendation:** Use **whisper.cpp + SwiftWhisper** because:
1. PhoWhisper (Vietnamese fine-tuned) significantly outperforms generic Whisper for Vietnamese
2. WhisperKit doesn't support custom fine-tuned models
3. Community has already converted PhoWhisper to GGML format

## Installation

### 1. Swift Package Dependencies

```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "1.2.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
]
```

### 2. Model Setup

```bash
# Option A: Use pre-converted GGML model (easier)
# Download from: https://huggingface.co/dongxiat/ggml-PhoWhisper-medium

# Option B: Convert yourself (more control)
git clone https://github.com/ggml-org/whisper.cpp
git clone https://github.com/openai/whisper
cd whisper.cpp/models

# Download PhoWhisper from HuggingFace
pip install huggingface_hub
huggingface-cli download vinai/PhoWhisper-medium --local-dir ./PhoWhisper-medium

# Convert to GGML
python convert-h5-to-ggml.py ./PhoWhisper-medium ../whisper .
mv ggml-model.bin ggml-phowhisper-medium.bin
```

### 3. CoreML Model (Optional, for 2-3x speedup)

```bash
# Generate CoreML encoder model for Apple Neural Engine acceleration
# Requires: coremltools, torch
python whisper.cpp/models/convert-whisper-to-coreml.py \
    --model medium \
    --encoder-only
```

Place the generated `*-encoder.mlmodelc` alongside your GGML model file.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftWhisper | WhisperKit | If Vietnamese accuracy is not critical and want simpler setup |
| SwiftWhisper | whisper.cpp C API directly | If need maximum control or encountering Swift wrapper issues |
| PhoWhisper-medium | PhoWhisper-small | If targeting 8GB RAM Macs or need faster inference |
| PhoWhisper-medium | Standard Whisper large-v3 | Never for Vietnamese - PhoWhisper significantly better |
| KeyboardShortcuts | HotKey | If only need hardcoded shortcuts without UI customization |
| SwiftUI MenuBarExtra | NSStatusItem (AppKit) | If need macOS 12 support (MenuBarExtra requires macOS 13) |
| CGEvent text insertion | NSPasteboard + Cmd+V | Fallback for apps that block CGEvent |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Python Whisper** | 6-7x slower than whisper.cpp on CPU, no native macOS integration | whisper.cpp via SwiftWhisper |
| **Standard Whisper for Vietnamese** | Generic model has ~15-20% WER vs PhoWhisper's 5% | PhoWhisper fine-tuned model |
| **Apple Speech Recognition** | No Vietnamese support, online-only for good accuracy | Local whisper.cpp |
| **Google/Azure STT APIs** | Online dependency, privacy concerns, not offline | Local PhoWhisper |
| **Electron/web wrappers** | Performance overhead, larger app size, not native | Native Swift/SwiftUI |
| **PhoWhisper-large** | 2x RAM of medium, only 0.3% WER improvement | PhoWhisper-medium |

## Stack Patterns by Variant

**If targeting macOS 13 (Ventura):**
- Use NSStatusItem instead of MenuBarExtra
- SwiftWhisper still works
- KeyboardShortcuts still works

**If RAM-constrained (8GB Macs):**
- Use PhoWhisper-small (244M params, ~600MB RAM)
- Still achieves 6.33% WER on VIVOS
- Trade accuracy for memory

**If need maximum accuracy:**
- Use PhoWhisper-large (1.55B params)
- Requires ~3GB RAM for model
- Only 0.3% WER improvement over medium
- Longer inference time

**If need real-time streaming display:**
- Enable whisper.cpp streaming mode
- Use smaller model (small or base)
- Trade accuracy for responsiveness

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| SwiftWhisper 1.2.0 | whisper.cpp v1.8.x | Uses latest GGML format |
| SwiftUI MenuBarExtra | macOS 13+ | Use NSStatusItem for macOS 12 |
| KeyboardShortcuts 2.0 | macOS 12+ | Swift 5.9+ required |
| CoreML Whisper | macOS 13+ | ANE acceleration |
| CGEvent tap | macOS 10.15+ | Sandbox compatible since Catalina |

## Required Permissions

| Permission | TCC Service | Purpose | User Prompt |
|------------|-------------|---------|-------------|
| **Microphone** | `kTCCServiceMicrophone` | Audio capture | "App wants to access microphone" |
| **Accessibility** | `kTCCServiceAccessibility` | CGEvent text insertion | System Settings > Privacy > Accessibility |
| **Input Monitoring** | `kTCCServiceListenEvent` | Global hotkey capture | System Settings > Privacy > Input Monitoring |

**Note:** Accessibility permission requires user to manually enable in System Settings. Cannot be programmatically granted. Design clear onboarding flow.

## Info.plist Keys Required

```xml
<!-- Microphone access -->
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for speech-to-text transcription.</string>

<!-- Hide from Dock (menu bar only) -->
<key>LSUIElement</key>
<true/>

<!-- Accessibility usage -->
<key>NSAppleEventsUsageDescription</key>
<string>This app needs accessibility access to insert transcribed text.</string>
```

## Performance Expectations (Apple Silicon)

| Model | M1 | M2 | M3/M4 | Notes |
|-------|----|----|-------|-------|
| PhoWhisper-small | ~0.3x RT | ~0.25x RT | ~0.2x RT | Real-time capable |
| PhoWhisper-medium | ~0.5x RT | ~0.4x RT | ~0.3x RT | Near real-time with CoreML |
| PhoWhisper-large | ~1.0x RT | ~0.8x RT | ~0.6x RT | Slight delay acceptable |

*RT = Real-time (1x means audio duration = processing time)*

**With CoreML enabled:** Add 2-3x speedup to above numbers.

## Sources

- [whisper.cpp GitHub](https://github.com/ggml-org/whisper.cpp) - v1.8.3 release, CoreML support details
- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) - Swift Package Index, API documentation
- [PhoWhisper GitHub](https://github.com/VinAIResearch/PhoWhisper) - WER benchmarks, model weights
- [PhoWhisper Paper](https://arxiv.org/abs/2406.02555) - ICLR 2024 Tiny Papers
- [HuggingFace vinai/PhoWhisper-large](https://huggingface.co/vinai/PhoWhisper-large) - Model cards
- [HuggingFace dongxiat/ggml-PhoWhisper-medium](https://huggingface.co/dongxiat/ggml-PhoWhisper-medium) - Pre-converted GGML
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey library
- [Apple CGEvent Documentation](https://developer.apple.com/documentation/coregraphics/cgevent) - Text insertion API
- [Voicci Whisper Benchmarks](https://www.voicci.com/blog/apple-silicon-whisper-performance.html) - Apple Silicon performance

---
*Stack research for: macOS Vietnamese Speech-to-Text Application*
*Researched: 2026-01-17*
