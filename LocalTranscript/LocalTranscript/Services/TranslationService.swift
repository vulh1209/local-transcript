import Foundation
import Translation
import NaturalLanguage
import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.voicetype.localtranscript", category: "TranslationService")

/// Helper view that uses translationTask to perform translations
/// The Translation framework requires SwiftUI to obtain a TranslationSession
@available(macOS 15.0, *)
private struct TranslationHelper: View {
    let text: String
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let onComplete: (Result<String, Error>) -> Void

    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration) { session in
                do {
                    let response = try await session.translate(text)
                    await MainActor.run {
                        onComplete(.success(response.targetText))
                    }
                } catch {
                    await MainActor.run {
                        onComplete(.failure(error))
                    }
                }
            }
            .onAppear {
                // Trigger translation by setting the configuration
                configuration = TranslationSession.Configuration(
                    source: sourceLanguage,
                    target: targetLanguage
                )
            }
    }
}

@available(macOS 15.0, *)
@Observable
class TranslationService {
    enum TranslationState: Equatable {
        case idle
        case translating
        case completed(String)
        case error(TranslationError)
    }

    enum TranslationError: LocalizedError, Equatable {
        case noTextSelected
        case accessibilityNotGranted
        case languagePacksNotInstalled
        case translationFailed(String)
        case textTooLong

        var errorDescription: String? {
            switch self {
            case .noTextSelected:
                return "No text selected"
            case .accessibilityNotGranted:
                return "Accessibility permission required"
            case .languagePacksNotInstalled:
                return "Language packs not installed. Go to System Settings > Translation Languages"
            case .translationFailed(let message):
                return "Translation failed: \(message)"
            case .textTooLong:
                return "Selected text is too long"
            }
        }
    }

    private(set) var state: TranslationState = .idle
    private(set) var lastTranslation: String = ""

    /// Maximum text length to translate (10KB as per spec edge cases)
    private let maxTextLength: Int = 10_000

    private let textInsertionService: TextInsertionService
    @ObservationIgnored private var statusPanel: StatusIndicatorPanel?

    init(textInsertionService: TextInsertionService = TextInsertionService()) {
        self.textInsertionService = textInsertionService
    }

    var isTranslating: Bool {
        if case .translating = state { return true }
        return false
    }

    // MARK: - Public Methods

    /// Main entry point: translates currently selected text
    /// Called by hotkey handler from AppState
    @MainActor
    func translateSelection() async {
        logger.info("translateSelection called, current state: \(String(describing: self.state))")

        // Ignore if already translating (concurrent request protection per spec edge cases)
        guard !isTranslating else {
            logger.info("Already translating, ignoring request")
            return
        }

        // Reset from previous completed/error states
        state = .idle

        // Read selected text via Accessibility API
        guard let selectedText = textInsertionService.getSelectedText() else {
            logger.warning("No text selected")
            showStatusPanel(.error(message: TranslationError.noTextSelected.localizedDescription))
            state = .error(.noTextSelected)
            return
        }

        // Check text length (edge case: very long text)
        guard selectedText.count <= maxTextLength else {
            logger.warning("Text too long: \(selectedText.count) chars, max \(self.maxTextLength)")
            showStatusPanel(.error(message: TranslationError.textTooLong.localizedDescription))
            state = .error(.textTooLong)
            return
        }

        logger.info("Selected text: '\(selectedText.prefix(50))...' (\(selectedText.count) chars)")

        // Show translating status
        showStatusPanel(.translating)
        state = .translating

        do {
            // Check language pack availability (to be implemented in subtask-5-2)
            try await checkLanguageAvailability()

            // Perform translation (to be implemented in subtask-5-3)
            let translatedText = try await translate(text: selectedText)

            logger.info("Translation result: '\(translatedText.prefix(50))...'")
            lastTranslation = translatedText
            state = .completed(translatedText)

            // Show success indicator
            showStatusPanel(.translated(translatedText))

            // Insert translated text at cursor (replaces selection)
            try await textInsertionService.insertText(translatedText)
            logger.info("Translated text inserted successfully")

        } catch let error as TranslationError {
            logger.error("Translation error: \(error.localizedDescription)")
            showStatusPanel(.error(message: error.localizedDescription))
            state = .error(error)
        } catch {
            logger.error("Unexpected translation error: \(error.localizedDescription)")
            let translationError = TranslationError.translationFailed(error.localizedDescription)
            showStatusPanel(.error(message: translationError.localizedDescription))
            state = .error(translationError)
        }
    }

    /// Reset to idle state
    func reset() {
        state = .idle
    }

    // MARK: - Language Availability (subtask-5-2)

    /// Checks if English and Vietnamese language packs are installed
    /// Throws TranslationError.languagePacksNotInstalled if not available
    private func checkLanguageAvailability() async throws {
        logger.info("Checking language availability for EN↔VI translation")

        let availability = LanguageAvailability()
        let english = Locale.Language(identifier: "en")
        let vietnamese = Locale.Language(identifier: "vi")

        // Check EN → VI availability
        let enToViStatus = await availability.status(from: english, to: vietnamese)
        logger.info("EN→VI status: \(String(describing: enToViStatus))")

        // Check VI → EN availability
        let viToEnStatus = await availability.status(from: vietnamese, to: english)
        logger.info("VI→EN status: \(String(describing: viToEnStatus))")

        // Both directions must be installed for bidirectional translation
        guard enToViStatus == .installed && viToEnStatus == .installed else {
            logger.warning("Language packs not installed. EN→VI: \(String(describing: enToViStatus)), VI→EN: \(String(describing: viToEnStatus))")
            throw TranslationError.languagePacksNotInstalled
        }

        logger.info("Language packs verified: EN↔VI available")
    }

    // MARK: - Translation (subtask-5-3)

    /// Performs bidirectional EN<->VI translation with auto-detection
    /// Uses Apple Translation framework with NLLanguageRecognizer for language detection
    @MainActor
    private func translate(text: String) async throws -> String {
        logger.info("Starting translation for text (\(text.count) chars)")

        // Detect source language using NLLanguageRecognizer
        // This is more reliable than Translation API's auto-detect for short text
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let detectedLanguage = recognizer.dominantLanguage

        logger.info("Detected language: \(String(describing: detectedLanguage))")

        // Determine translation direction based on detected language
        let sourceLanguage: Locale.Language
        let targetLanguage: Locale.Language

        if detectedLanguage == .vietnamese {
            // Vietnamese → English
            sourceLanguage = Locale.Language(identifier: "vi")
            targetLanguage = Locale.Language(identifier: "en")
            logger.info("Translation direction: VI → EN")
        } else {
            // English → Vietnamese (default for English or unknown languages)
            // Per pitfalls research: treat unknown as English since most users will
            // be translating English to Vietnamese
            sourceLanguage = Locale.Language(identifier: "en")
            targetLanguage = Locale.Language(identifier: "vi")
            logger.info("Translation direction: EN → VI")
        }

        // Use a continuation to bridge between SwiftUI's translationTask and our async method
        return try await withCheckedThrowingContinuation { continuation in
            // Create a temporary window to host the translation helper view
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: [],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.ignoresMouseEvents = true

            var hasCompleted = false

            let helperView = TranslationHelper(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            ) { result in
                guard !hasCompleted else { return }
                hasCompleted = true
                window.close()
                switch result {
                case .success(let translatedText):
                    logger.info("Translation completed: '\(translatedText.prefix(50))...'")
                    continuation.resume(returning: translatedText)
                case .failure(let error):
                    logger.error("TranslationSession error: \(error.localizedDescription)")
                    continuation.resume(throwing: TranslationError.translationFailed(error.localizedDescription))
                }
            }

            window.contentView = NSHostingView(rootView: helperView)
            window.orderFront(nil)
        }
    }

    // MARK: - Status Panel Management

    @MainActor
    private func showStatusPanel(_ state: StatusIndicatorState) {
        if statusPanel == nil {
            statusPanel = StatusIndicatorPanel()
        }
        statusPanel?.updateState(state)
        statusPanel?.orderFront(nil)
    }

    @MainActor
    private func hideStatusPanel() {
        statusPanel?.close()
        statusPanel = nil
    }
}
