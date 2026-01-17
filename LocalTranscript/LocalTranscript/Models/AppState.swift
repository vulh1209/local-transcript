import SwiftUI

@Observable
class AppState {
    let permissionManager = PermissionManager()
    let modelManager = ModelManager()
    let launchManager = LaunchManager()
    let audioRecorder = AudioRecorder()
    let hotkeyService = HotkeyService()

    // TranscriptionService coordinates everything
    // Note: Cannot use lazy var with @Observable macro, so using @ObservationIgnored
    @ObservationIgnored
    private var _transcriptionService: TranscriptionService?

    var transcriptionService: TranscriptionService {
        if let service = _transcriptionService {
            return service
        }
        let service = TranscriptionService(audioRecorder: audioRecorder, modelManager: modelManager)
        _transcriptionService = service
        return service
    }

    // Derived from transcription service state
    var isRecording: Bool {
        transcriptionService.isRecording
    }

    init() {
        setupHotkeyBindings()
    }

    private func setupHotkeyBindings() {
        hotkeyService.bind(
            onStart: { [weak self] in
                guard let self else { return }
                try await self.transcriptionService.startRecording()
            },
            onStop: { [weak self] in
                guard let self else { return }
                await self.transcriptionService.stopRecording()
            }
        )
    }
}
