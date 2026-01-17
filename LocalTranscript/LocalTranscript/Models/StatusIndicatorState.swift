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

    /// Duration to auto-hide this state (nil = don't auto-hide)
    var autoDismissDelay: TimeInterval? {
        switch self {
        case .recording, .transcribing, .downloading:
            return nil  // Stay visible until state changes
        case .error:
            return 3.0  // Show error for 3 seconds
        case .languageChanged:
            return 1.5  // Brief confirmation
        }
    }
}
