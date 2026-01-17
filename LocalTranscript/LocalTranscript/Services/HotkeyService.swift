import Foundation
import KeyboardShortcuts

// Register shortcut name with default key combination
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
}

enum RecordingMode: String, CaseIterable {
    case holdToTalk = "Hold to Talk"
    case toggle = "Toggle"
}

@Observable
class HotkeyService {
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
        // Load saved mode
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
