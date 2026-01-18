import Foundation

/// Controls how audio is segmented for transcription
enum SegmentMode: String, CaseIterable {
    /// Manual mode: hotkey release triggers transcription (existing behavior)
    case manual = "Manual"
    /// Auto-segment mode: VAD-triggered automatic segmentation
    case auto = "Auto-Segment"

    /// Display description for settings UI
    var description: String {
        switch self {
        case .manual:
            return "Press and hold to record, release to transcribe"
        case .auto:
            return "Automatic pause detection for hands-free dictation"
        }
    }
}
