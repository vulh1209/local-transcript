import AppKit
import CoreGraphics
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.voicetype.localtranscript", category: "TextInsertionService")

@Observable
class TextInsertionService {
    private let pasteboard = NSPasteboard.general

    enum InsertionError: LocalizedError {
        case accessibilityNotGranted
        case insertionFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityNotGranted:
                return "Accessibility permission not granted"
            case .insertionFailed:
                return "Failed to insert text"
            }
        }
    }

    /// Insert text at cursor position in any app
    /// Uses clipboard + Cmd+V as primary method (most compatible)
    @MainActor
    func insertText(_ text: String) async throws {
        logger.info("Inserting text: '\(text.prefix(50))...'")

        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            logger.error("Accessibility not granted")
            throw InsertionError.accessibilityNotGranted
        }

        // Try direct Accessibility insertion first (faster, no clipboard pollution)
        if tryDirectInsertion(text) {
            logger.info("Direct AX insertion succeeded")
            return
        }

        // Fallback to clipboard + paste
        logger.info("Falling back to clipboard + paste")
        try await insertViaClipboard(text)
    }

    /// Try direct text insertion via Accessibility API
    /// Returns true if successful, false if fallback needed
    private func tryDirectInsertion(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
        let element = focusedElement as! AXUIElement? else {
            logger.debug("No focused element found")
            return false
        }

        // Check if we can set text
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        ) == .success, settable.boolValue else {
            logger.debug("Element doesn't support text setting")
            return false
        }

        // Insert text at cursor (replaces selection, or inserts at cursor if no selection)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return result == .success
    }

    /// Insert text via clipboard and Cmd+V
    @MainActor
    private func insertViaClipboard(_ text: String) async throws {
        // Put text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        try await Task.sleep(for: .milliseconds(50))

        // Simulate Cmd+V
        simulatePaste()

        logger.info("Clipboard paste simulated")
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger.error("Failed to create CGEventSource")
            return
        }

        // Virtual key code 9 = 'V' key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        // Add Command modifier
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // Post events to focused application
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
