import Foundation
import KeyboardShortcuts
import AppKit

// Register shortcut names with default key combinations
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
    static let cycleLanguage = Self("cycleLanguage", default: .init(.l, modifiers: [.option]))
}

enum RecordingMode: String, CaseIterable {
    case holdToTalk = "Hold to Talk"
    case toggle = "Toggle"
}

@Observable
class HotkeyService {
    var mode: RecordingMode = .holdToTalk {
        didSet {
            // Stop active recording before switching modes (UAT Test 10)
            if isRecording {
                isRecording = false
                Task { await onStop?() }
            }
            UserDefaults.standard.set(mode.rawValue, forKey: "recordingMode")
            rebindHandlers()
        }
    }

    private var isRecording = false
    private var onStart: (() async throws -> Void)?
    private var onStop: (() async -> Void)?
    @ObservationIgnored private var statusPanel: StatusIndicatorPanel?

    init() {
        // Load saved mode
        if let savedMode = UserDefaults.standard.string(forKey: "recordingMode"),
           let mode = RecordingMode(rawValue: savedMode) {
            self.mode = mode
        }

        // Register language cycle hotkey
        KeyboardShortcuts.onKeyUp(for: .cycleLanguage) { [weak self] in
            Task { @MainActor in
                self?.cycleLanguageMode()
            }
        }
    }

    /// Cycles through language modes: Auto -> Vietnamese -> English -> Auto
    @MainActor
    private func cycleLanguageMode() {
        let currentRaw = UserDefaults.standard.string(forKey: "languageMode") ?? LanguageMode.auto.rawValue
        let current = LanguageMode(rawValue: currentRaw) ?? .auto

        let next: LanguageMode
        switch current {
        case .auto:
            next = .vietnamese
        case .vietnamese:
            next = .english
        case .english:
            next = .auto
        }

        UserDefaults.standard.set(next.rawValue, forKey: "languageMode")
        print("[HotkeyService] Language mode changed to: \(next.rawValue)")

        // Show brief visual feedback
        showLanguageChangeFeedback(next)
    }

    @MainActor
    private func showLanguageChangeFeedback(_ mode: LanguageMode) {
        if statusPanel == nil {
            statusPanel = StatusIndicatorPanel()
        }
        statusPanel?.updateState(.languageChanged(mode.rawValue))
        statusPanel?.orderFront(nil)
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
