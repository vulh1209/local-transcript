import Foundation

enum LanguageMode: String, CaseIterable {
    case auto = "Auto"
    case vietnamese = "Vietnamese"
    case english = "English"

    /// Returns the Whisper language code for this mode
    /// - nil means auto-detect
    /// - "vi" for Vietnamese
    /// - "en" for English
    var whisperLanguageCode: String? {
        switch self {
        case .auto:
            return nil
        case .vietnamese:
            return "vi"
        case .english:
            return "en"
        }
    }
}
