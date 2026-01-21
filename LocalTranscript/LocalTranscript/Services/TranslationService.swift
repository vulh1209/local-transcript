import Foundation
import Translation
import NaturalLanguage
import AppKit
import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.voicetype.localtranscript", category: "TranslationService")

/// Coordinator class that manages translation requests and results
/// This class is kept alive by the TranslationService to avoid lifecycle issues
@available(macOS 15.0, *)
private class TranslationCoordinator: ObservableObject {
    @Published var pendingRequest: TranslationRequest?
    var continuation: CheckedContinuation<String, Error>?

    struct TranslationRequest: Identifiable {
        let id: UUID
        let text: String
        let sourceLanguage: Locale.Language
        let targetLanguage: Locale.Language
    }

    func completeWithSuccess(_ text: String) {
        continuation?.resume(returning: text)
        continuation = nil
    }

    func completeWithError(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

/// Persistent view that handles translation using translationTask
@available(macOS 15.0, *)
private struct PersistentTranslationView: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @State private var configuration: TranslationSession.Configuration?
    @State private var currentRequestId: UUID?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration) { session in
                guard let request = coordinator.pendingRequest else {
                    logger.debug("translationTask called but no pending request")
                    return
                }
                logger.info("translationTask executing for request \(request.id)")
                do {
                    let response = try await session.translate(request.text)
                    logger.info("translationTask got response: \(response.targetText.prefix(30))...")
                    await MainActor.run {
                        coordinator.completeWithSuccess(response.targetText)
                    }
                } catch {
                    logger.error("translationTask error: \(error.localizedDescription)")
                    await MainActor.run {
                        coordinator.completeWithError(error)
                    }
                }
            }
            .onReceive(coordinator.$pendingRequest) { newRequest in
                guard let request = newRequest else {
                    return
                }

                // Only update if this is a new request
                guard request.id != currentRequestId else {
                    logger.debug("Ignoring duplicate request \(request.id)")
                    return
                }

                logger.info("onReceive: new request \(request.id)")
                currentRequestId = request.id

                // Always create a new configuration with correct source/target languages
                // (invalidate() reuses old config which may have wrong languages)
                logger.info("Creating configuration: \(request.sourceLanguage.languageCode?.identifier ?? "?") → \(request.targetLanguage.languageCode?.identifier ?? "?")")
                configuration = TranslationSession.Configuration(
                    source: request.sourceLanguage,
                    target: request.targetLanguage
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
        case timeout

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
            case .timeout:
                return "Translation timed out"
            }
        }
    }

    private(set) var state: TranslationState = .idle
    private(set) var lastTranslation: String = ""

    /// Maximum text length to translate (10KB as per spec edge cases)
    private let maxTextLength: Int = 10_000

    private let textInsertionService: TextInsertionService
    @ObservationIgnored private var statusPanel: StatusIndicatorPanel?

    // Persistent translation infrastructure - created once and reused
    @ObservationIgnored private var translationCoordinator: TranslationCoordinator?
    @ObservationIgnored private var translationWindow: NSWindow?

    init(textInsertionService: TextInsertionService = TextInsertionService()) {
        self.textInsertionService = textInsertionService
    }

    /// Ensures the persistent translation window is set up
    @MainActor
    private func ensureTranslationWindow() {
        guard translationWindow == nil else { return }

        let coordinator = TranslationCoordinator()
        translationCoordinator = coordinator

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
        window.isReleasedWhenClosed = false  // Important: don't release when closed

        let hostingView = NSHostingView(rootView: PersistentTranslationView(coordinator: coordinator))
        window.contentView = hostingView
        window.orderFront(nil)

        translationWindow = window
        logger.info("Persistent translation window created")
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

        // Check if focused element is editable BEFORE getting text
        // (clipboard operations may change focus)
        let isEditable = textInsertionService.isFocusedElementEditable()
        logger.info("Focused element editable (before copy): \(isEditable)")

        // Read selected text via clipboard (Cmd+C) - works with VSCode, Chrome, etc.
        guard let selectedText = await textInsertionService.getSelectedTextViaClipboard() else {
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

            // Use the editability state captured BEFORE clipboard operations
            // (checking again here would fail because focus may have changed)
            if isEditable {
                // Editable field: auto-paste the translated text
                try await textInsertionService.insertText(translatedText)
                logger.info("Translated text inserted into editable field")
                // Show brief success indicator
                showStatusPanel(.translated(translatedText), duration: 3.0)
            } else {
                // Non-editable: copy to clipboard and show popup for 15 seconds
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(translatedText, forType: .string)
                logger.info("Translated text copied to clipboard (non-editable context)")
                // Show translated text in popup for 15 seconds so user can read/copy
                showStatusPanel(.translated(translatedText), duration: 15.0)
            }

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

        // Ensure persistent translation window exists
        ensureTranslationWindow()

        guard let coordinator = translationCoordinator else {
            throw TranslationError.translationFailed("Translation coordinator not initialized")
        }

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

        // Create translation request
        let requestId = UUID()
        let request = TranslationCoordinator.TranslationRequest(
            id: requestId,
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        // Use continuation to wait for result
        return try await withCheckedThrowingContinuation { continuation in
            coordinator.continuation = continuation
            coordinator.pendingRequest = request
            logger.info("Request \(requestId) submitted, waiting for result...")
        }
    }

    // MARK: - Status Panel Management

    @MainActor
    private func showStatusPanel(_ state: StatusIndicatorState, duration: TimeInterval? = nil) {
        if statusPanel == nil {
            statusPanel = StatusIndicatorPanel()
        }
        statusPanel?.updateState(state)
        statusPanel?.orderFront(nil)

        // Auto-hide after duration if specified
        if let duration = duration {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                self.hideStatusPanel()
            }
        }
    }

    @MainActor
    private func hideStatusPanel() {
        statusPanel?.close()
        statusPanel = nil
    }
}
