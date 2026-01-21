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

    /// Returns the Apple Translation Locale.Language for this mode
    /// - nil means auto-detect (Translation framework will detect source language)
    /// - Vietnamese locale for .vietnamese
    /// - English locale for .english
    var translationLocale: Locale.Language? {
        switch self {
        case .auto:
            return nil
        case .vietnamese:
            return Locale.Language(identifier: "vi")
        case .english:
            return Locale.Language(identifier: "en")
        }
    }
}
