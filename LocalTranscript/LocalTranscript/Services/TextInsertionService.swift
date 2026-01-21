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

    /// Get currently selected text using clipboard (Cmd+C)
    /// Works with most apps including VSCode, Chrome, Terminal
    /// Returns nil if no text is selected or copy fails
    @MainActor
    func getSelectedTextViaClipboard() async -> String? {
        // Check accessibility permission (needed for simulating Cmd+C)
        guard AXIsProcessTrusted() else {
            logger.debug("Cannot get selected text: Accessibility not granted")
            return nil
        }

        // Save current clipboard content and change count to restore later
        let savedClipboard = pasteboard.string(forType: .string)
        let initialChangeCount = pasteboard.changeCount

        // Simulate Cmd+C to copy selection
        simulateCopy()

        // Poll for clipboard change with timeout
        // Some apps (especially Electron apps) need more time to process copy
        var copiedText: String?
        let maxAttempts = 10
        let pollInterval: UInt64 = 50_000_000 // 50ms in nanoseconds

        for attempt in 1...maxAttempts {
            try? await Task.sleep(nanoseconds: pollInterval)

            // Check if clipboard changed
            if pasteboard.changeCount != initialChangeCount {
                copiedText = pasteboard.string(forType: .string)
                logger.debug("Clipboard changed after \(attempt * 50)ms")
                break
            }
        }

        // Restore previous clipboard content if we got new text
        if let saved = savedClipboard, copiedText != nil && copiedText != saved {
            // Small delay before restoring
            try? await Task.sleep(for: .milliseconds(50))
            pasteboard.clearContents()
            pasteboard.setString(saved, forType: .string)
        }

        guard let text = copiedText, !text.isEmpty else {
            logger.debug("No text copied from selection (clipboard unchanged)")
            return nil
        }

        logger.info("Got selected text via clipboard: '\(text.prefix(50))...' (\(text.count) chars)")
        return text
    }

    /// Get currently selected text from focused element via Accessibility API
    /// Returns nil if no text is selected or accessibility permission not granted
    func getSelectedText() -> String? {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            logger.debug("Cannot get selected text: Accessibility not granted")
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
        let element = focusedElement as! AXUIElement? else {
            logger.debug("No focused element found for text selection")
            return nil
        }

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        ) == .success,
        let text = selectedText as? String,
        !text.isEmpty else {
            logger.debug("No text selected or selection is empty")
            return nil
        }

        logger.info("Got selected text: '\(text.prefix(50))...' (\(text.count) chars)")
        return text
    }

    /// Check if the currently focused element is editable (can accept text input)
    /// Uses multiple strategies: AXUIElement check, then fallback to app bundle ID heuristics
    func isFocusedElementEditable() -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }

        // Strategy 1: Try direct AXUIElement focused element check
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        if AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
        let element = focusedElement as! AXUIElement? {
            // Check if element supports setting selected text (indicates editability)
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(
                element,
                kAXSelectedTextAttribute as CFString,
                &settable
            ) == .success {
                let isEditable = settable.boolValue
                logger.debug("Focused element editable (AX check): \(isEditable)")
                return isEditable
            }
        }

        // Strategy 2: Fallback to app-based heuristics for Electron/web apps
        // These apps often don't expose focused elements properly via AXUIElement
        logger.debug("No focused element found, checking frontmost app")

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            logger.debug("Could not determine frontmost app")
            return false
        }

        logger.debug("Frontmost app: \(bundleId)")

        // Known code editors and text-focused apps where selection likely means editable context
        let editableApps: Set<String> = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.todesktop.230313mzl4w4u92",  // Cursor
            "com.sublimetext.4",
            "com.sublimetext.3",
            "com.jetbrains.intellij",
            "com.jetbrains.WebStorm",
            "com.jetbrains.pycharm",
            "com.apple.dt.Xcode",
            "com.apple.TextEdit",
            "com.apple.Notes",
            "com.googlecode.iterm2",
            "com.apple.Terminal",
            "io.alacritty",
            "net.kovidgoyal.kitty",
            "org.vim.MacVim",
            "com.github.atom",  // Atom (legacy)
            "abnerworks.Typora",
            "md.obsidian",
            "com.electron.logseq",
            "notion.id",
        ]

        let isKnownEditor = editableApps.contains(bundleId)
        logger.debug("App \(bundleId) is known editor: \(isKnownEditor)")
        return isKnownEditor
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

    private func simulateCopy() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger.error("Failed to create CGEventSource")
            return
        }

        // Virtual key code 8 = 'C' key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)

        // Add Command modifier
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // Post events to focused application
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
