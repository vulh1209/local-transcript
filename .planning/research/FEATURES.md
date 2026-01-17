# Feature Research

**Domain:** macOS Vietnamese Speech-to-Text Dictation App
**Researched:** 2026-01-17
**Confidence:** MEDIUM (based on WebSearch verified against official sources and GitHub repos)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Hold-to-talk activation** | Primary input mode; users expect immediate recording when holding key | LOW | Standard macOS hotkey pattern. Similar to Easy Voice Input's Fn hold. |
| **Toggle on/off mode** | Users need hands-free option for longer dictation | LOW | Secondary mode. Press once to start, press again to stop. |
| **Global hotkey configuration** | Works from any app without switching | LOW | macOS accessibility permission required. Standard pattern. |
| **Text insertion at cursor** | Core function - text must appear where user is typing | MEDIUM | Requires accessibility API. Can use paste fallback. |
| **Visual recording indicator** | Users must know when mic is active | LOW | Menu bar icon state change, waveform, or pulsing indicator. PulseScribe: "spinners are useless." |
| **Audio feedback on start/stop** | Confirm recording state without looking | LOW | Optional sounds on start, stop, insert. Dictop does this well. |
| **Offline operation** | Core value proposition; no internet dependency | LOW | Using local Whisper/PhoWhisper models. Already decided. |
| **Basic punctuation handling** | "Hello comma how are you" should insert comma | MEDIUM | Whisper handles this automatically for most cases. |
| **Multi-line text support** | Paragraphs, not just single lines | LOW | Include newline/paragraph voice commands or natural pause detection. |
| **Settings persistence** | Preferences saved between sessions | LOW | macOS UserDefaults standard pattern. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **PhoWhisper model option** | State-of-art Vietnamese accuracy (4.67 WER vs Whisper's higher) | MEDIUM | VinAI's fine-tuned model. 5 sizes available (39M-1.55B params). Key differentiator for Vietnamese users. |
| **Vietnamese tone handling** | Proper diacritics and tonal marks | LOW | PhoWhisper trained on 844hr Vietnamese data with diverse accents. Automatic with right model. |
| **Custom vocabulary** | Technical terms, names, jargon for "vibe coding" | MEDIUM | Superwhisper/Wispr Flow both have this. Essential for developer workflows with project-specific terms. |
| **Developer-optimized mode** | Prompts formatted for AI tools (Cursor, Claude) | MEDIUM | Speechly has "Prompt Mode" for this. Format output for AI consumption. |
| **Per-app insertion modes** | Paste vs keystroke simulation per target app | MEDIUM | Some apps handle paste differently. IDEs may need keystroke simulation. |
| **Transcription history** | Review/reuse recent transcriptions | LOW | Pipit combines clipboard + transcription history. Useful for repeated phrases. |
| **Low resource usage** | Minimal CPU/RAM when idle | MEDIUM | Wispr Flow criticized for 800MB RAM, 8% CPU when idle. Opportunity to be lighter. |
| **Model selection UI** | Choose between speed (tiny) vs accuracy (large) | LOW | Let users pick PhoWhisper tiny/base/small/medium/large based on their hardware. |
| **Bilingual Vietnamese-English** | Handle code-switching common in dev work | HIGH | Recent research (2025) on cross-lingual phoneme recognition. PhoWhisper encoder can be leveraged. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Real-time streaming transcription** | "See words as I speak" | Distracting, restricts movement, increases complexity. Users noted it's "exciting initially but distracting in practice." | Show brief processing indicator, then insert complete text. |
| **Cloud AI post-processing (LLM cleanup)** | Better grammar, remove filler words | Breaks offline-only promise. Adds latency. Privacy concerns. Cloud costs. | Optional local LLM mode if user brings their own. Not in MVP. |
| **Auto-punctuation learning** | "Learn my punctuation style" | Inconsistent results, users report frustration. Apple dictation "doesn't reliably learn from corrections." | Use Whisper's built-in punctuation; provide manual overrides. |
| **Voice commands for editing** | "Delete last word", "go back" | Significant complexity, requires NLU layer, conflicts with actual dictation. | Use keyboard for editing. Focus on doing one thing well. |
| **Multi-speaker support** | Meetings, pair programming | Out of scope for single-user dictation. Adds complexity. | Keep scope to single-user voice typing. |
| **Automatic language switching** | Detect when user switches languages | Unreliable detection, causes errors. Users report multi-language as "all but unusable" with Apple. | Manual mode selection, or optimize for Vietnamese with English fallback. |
| **Always-on listening** | "Hey assistant" wake word | Battery drain, privacy concerns, complexity. Not needed for active dictation. | Explicit activation via hotkey only. |
| **Auto-send/auto-submit** | Automatically submit forms | Dangerous - no opportunity to review. Users report Apple dictation changing correct words to incorrect. | Always require explicit user action to send. |

## Feature Dependencies

```
[Menu Bar App Shell]
    |
    +---> [Global Hotkey System]
    |         |
    |         +---> [Hold-to-Talk Mode]
    |         |
    |         +---> [Toggle Mode]
    |
    +---> [Audio Capture]
    |         |
    |         +---> [Whisper/PhoWhisper Engine]
    |                   |
    |                   +---> [Text Processing]
    |                             |
    |                             +---> [Text Insertion]
    |                                       |
    |                                       +---> [Clipboard Paste Method]
    |                                       |
    |                                       +---> [Accessibility Type Method]
    |
    +---> [Visual Indicator]
    |
    +---> [Settings UI]
              |
              +---> [Model Selection]
              |
              +---> [Hotkey Configuration]
              |
              +---> [Custom Vocabulary] (depends on Text Processing)
```

### Dependency Notes

- **Hold-to-Talk requires Global Hotkey System:** Must capture keyDown and keyUp events
- **Toggle Mode requires Global Hotkey System:** Must toggle state on keyDown
- **Text Insertion requires Accessibility permission:** For paste OR keystroke simulation
- **Model Selection requires Settings UI:** User must be able to choose model
- **Custom Vocabulary enhances Text Processing:** Post-processing step before insertion
- **PhoWhisper Engine requires model download:** First-run experience must handle this

## MVP Definition

### Launch With (v1)

Minimum viable product - what's needed to validate the concept.

- [x] **Menu bar app shell** - Resident app with status indicator
- [x] **Hold-to-talk activation** - Primary input mode, core UX
- [x] **Toggle on/off mode** - Secondary mode for longer dictation
- [x] **Global hotkey (configurable)** - User can set preferred key combo
- [x] **Audio capture and transcription** - Using PhoWhisper-small or -base
- [x] **Text insertion at cursor** - Via clipboard paste (most compatible)
- [x] **Visual recording indicator** - Menu bar icon change
- [x] **Audio feedback** - Start/stop sounds
- [x] **Basic settings** - Model selection, hotkey config

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Custom vocabulary** - Add when users request specific terms
- [ ] **Transcription history** - Add when users want to review/reuse
- [ ] **Per-app insertion modes** - Add when specific app issues reported
- [ ] **Multiple model sizes** - Start with one, add options based on feedback
- [ ] **Developer-optimized mode** - Add when vibe-coding workflow validated

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Bilingual Vietnamese-English** - Complex, needs more research
- [ ] **Local LLM post-processing** - Only if users bring their own models
- [ ] **Export/backup settings** - Nice for power users, not essential

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Hold-to-talk | HIGH | LOW | P1 |
| Toggle mode | HIGH | LOW | P1 |
| Text insertion | HIGH | MEDIUM | P1 |
| Visual indicator | HIGH | LOW | P1 |
| Audio feedback | MEDIUM | LOW | P1 |
| PhoWhisper integration | HIGH | MEDIUM | P1 |
| Hotkey configuration | MEDIUM | LOW | P1 |
| Model selection | MEDIUM | LOW | P2 |
| Custom vocabulary | MEDIUM | MEDIUM | P2 |
| Transcription history | LOW | LOW | P2 |
| Per-app insertion | LOW | MEDIUM | P3 |
| Bilingual mode | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Apple Dictation | Superwhisper | Wispr Flow | VoiceInk | **Our Approach** |
|---------|-----------------|--------------|------------|----------|------------------|
| Offline | Partial (some languages) | Yes (local models) | No (cloud) | Yes | **Yes (core value)** |
| Vietnamese | Generic Whisper | Generic Whisper | Cloud ASR | Generic Whisper | **PhoWhisper (optimized)** |
| Hold-to-talk | No | Unknown | No | Unknown | **Yes (primary mode)** |
| Toggle mode | Yes (keyboard shortcut) | Yes | Yes | Yes | **Yes (secondary mode)** |
| Custom vocabulary | No | Yes | Yes | Unknown | **v1.x** |
| LLM cleanup | No | Yes (cloud) | Yes (cloud) | No | **No (offline purity)** |
| Price | Free | $15/mo or $149/yr | $12-15/mo | $25 one-time | **TBD (likely one-time)** |
| Developer focus | No | Partial | Yes (vibe coding) | No | **Yes (prompt mode v1.x)** |

### Competitive Positioning

**Unique value proposition:** The only offline macOS dictation app optimized specifically for Vietnamese with PhoWhisper models.

- vs **Apple Dictation**: Better Vietnamese accuracy, hold-to-talk mode, always offline
- vs **Superwhisper/Wispr Flow**: Truly offline (no cloud dependency), Vietnamese-optimized
- vs **VoiceInk**: Vietnamese-specific model (PhoWhisper vs generic Whisper)

## Sources

### Official/High Confidence
- [PhoWhisper GitHub](https://github.com/VinAIResearch/PhoWhisper) - Vietnamese ASR model details, benchmarks
- [PhoWhisper Paper](https://arxiv.org/abs/2406.02555) - 844hr training data, WER benchmarks
- [Apple Dictation Support](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) - Built-in macOS dictation features
- [Superwhisper Docs](https://superwhisper.com/docs/modes/custom) - Mode system, custom vocabulary

### Market Research/Medium Confidence
- [TechCrunch Dictation Apps 2025](https://techcrunch.com/2025/12/30/the-best-ai-powered-dictation-apps-of-2025/) - Market overview
- [Wispr Flow Pricing](https://wisprflow.ai/pricing) - Feature comparison
- [Vibe Coding Overview](https://wisprflow.ai/vibe-coding) - Developer workflow context
- [Addy Osmani on Speech-to-Code](https://addyo.substack.com/p/speech-to-code-vibe-coding-with-voice) - Developer dictation patterns

### UX Research/Medium Confidence
- [Apple Community - Dictation Complaints](https://discussions.apple.com/thread/256079092) - Common user frustrations
- [PulseScribe](https://pulsescribe.me) - Visual indicator UX patterns
- [Dictop](https://dictop.com/) - Audio feedback patterns
- [Easy Voice Input](https://tianyu19920816.github.io/VoiceInputApp/) - Hold-to-talk pattern

---
*Feature research for: Vietnamese Speech-to-Text macOS App*
*Researched: 2026-01-17*
