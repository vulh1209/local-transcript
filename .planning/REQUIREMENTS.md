# Requirements: VoiceType

**Defined:** 2025-01-17
**Core Value:** Noi tieng Viet, ra text chinh xac, khong can internet.

## v1 Requirements

### Activation

- [ ] **ACT-01**: User can hold hotkey to record, release to transcribe
- [ ] **ACT-02**: User can toggle recording on/off with hotkey
- [ ] **ACT-03**: User can configure custom hotkey in settings
- [ ] **ACT-04**: Global hotkey works from any app

### Recording

- [ ] **REC-01**: App captures audio from microphone
- [ ] **REC-02**: Visual indicator shows when recording is active (menu bar)
- [ ] **REC-03**: Floating indicator shows when recording is active
- [ ] **REC-04**: Audio feedback (beep) plays on recording start
- [ ] **REC-05**: Audio feedback (beep) plays on recording stop

### Transcription

- [ ] **TRS-01**: App transcribes Vietnamese speech to text using local model
- [ ] **TRS-02**: Transcription works 100% offline (no internet required)
- [ ] **TRS-03**: App uses PhoWhisper model for Vietnamese accuracy
- [ ] **TRS-04**: Basic punctuation is included in transcription
- [ ] **TRS-05**: Multi-line text is supported (paragraph breaks)

### Text Output

- [ ] **OUT-01**: Transcribed text is inserted at cursor in focused app
- [ ] **OUT-02**: Text insertion works in any macOS app
- [ ] **OUT-03**: Fallback to clipboard paste if direct insertion fails

### Settings

- [ ] **SET-01**: User can choose between PhoWhisper model sizes (tiny/base/medium)
- [ ] **SET-02**: User preferences persist between app launches
- [ ] **SET-03**: Settings accessible from menu bar icon

### History

- [ ] **HST-01**: App stores recent transcriptions
- [ ] **HST-02**: User can view transcription history
- [ ] **HST-03**: User can copy text from history

### App Shell

- [ ] **APP-01**: App runs as menu bar app (no dock icon)
- [ ] **APP-02**: App starts on login (optional, configurable)
- [ ] **APP-03**: App requests necessary permissions (microphone, accessibility)

## v2 Requirements

### Custom Vocabulary

- **VOC-01**: User can add custom words/terms for better recognition
- **VOC-02**: Custom vocabulary persists between sessions

### Developer Mode

- **DEV-01**: Developer-optimized mode formats output for AI prompts
- **DEV-02**: Mode toggle in settings

### Translation (Future)

- **TRN-01**: Optional auto-translate Vietnamese to English
- **TRN-02**: Separate hotkey for translate mode

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time streaming transcription | Uu tien accuracy, streaming gay phan tan |
| Cloud LLM cleanup | Pha vo offline-only promise |
| Voice commands ("delete last word") | Qua phuc tap, ngoai scope dictation |
| Auto language switching | Khong dang tin cay |
| Always-on listening | Battery drain, privacy concerns |
| Auto-send/submit | Nguy hiem, khong co co hoi review |
| Multi-speaker support | Ngoai scope single-user dictation |
| Windows/Linux | macOS only |
| Mobile app | Desktop only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ACT-01 | Phase 3 | Pending |
| ACT-02 | Phase 3 | Pending |
| ACT-03 | Phase 3 | Pending |
| ACT-04 | Phase 3 | Pending |
| REC-01 | Phase 2 | Pending |
| REC-02 | Phase 2 | Pending |
| REC-03 | Phase 2 | Pending |
| REC-04 | Phase 2 | Pending |
| REC-05 | Phase 2 | Pending |
| TRS-01 | Phase 2 | Pending |
| TRS-02 | Phase 2 | Pending |
| TRS-03 | Phase 2 | Pending |
| TRS-04 | Phase 2 | Pending |
| TRS-05 | Phase 2 | Pending |
| OUT-01 | Phase 3 | Pending |
| OUT-02 | Phase 3 | Pending |
| OUT-03 | Phase 3 | Pending |
| SET-01 | Phase 4 | Pending |
| SET-02 | Phase 1 | Pending |
| SET-03 | Phase 1 | Pending |
| HST-01 | Phase 4 | Pending |
| HST-02 | Phase 4 | Pending |
| HST-03 | Phase 4 | Pending |
| APP-01 | Phase 1 | Pending |
| APP-02 | Phase 1 | Pending |
| APP-03 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2025-01-17*
*Last updated: 2025-01-17 after roadmap creation*
