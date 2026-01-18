import Foundation

/// Represents all possible states for the floating status indicator panel.
enum StatusIndicatorState: Equatable {
    /// Recording audio from microphone
    case recording
    /// Processing audio through Whisper model
    case transcribing
    /// Downloading model (first-time setup)
    case downloading(progress: Double)
    /// Error occurred during operation
    case error(message: String)
    /// Language mode was changed (brief feedback)
    case languageChanged(String)
    /// Recording in continuous/auto-segment mode (shows queue depth)
    case continuousRecording(pendingSegments: Int)
    /// Brief flash when segment boundary detected (before transcription starts)
    case segmentDetected

    /// Duration to auto-hide this state (nil = don't auto-hide)
    var autoDismissDelay: TimeInterval? {
        switch self {
        case .recording, .transcribing, .downloading, .continuousRecording:
            return nil  // Stay visible until state changes
        case .error:
            return 3.0  // Show error for 3 seconds
        case .languageChanged:
            return 1.5  // Brief confirmation
        case .segmentDetected:
            return 0.5  // Very brief flash (500ms)
        }
    }
}
