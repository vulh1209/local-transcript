import AppKit

/// A floating panel that displays status indicators for various app states.
/// Shows recording, transcribing, downloading, error, and language change states.
class StatusIndicatorPanel: NSPanel {
    private let containerView: NSView
    private let iconView: NSImageView
    private let textLabel: NSTextField
    private let progressBar: NSProgressIndicator

    private var autoDismissWorkItem: DispatchWorkItem?

    // Panel sizing
    private static let minWidth: CGFloat = 140
    private static let maxWidth: CGFloat = 220
    private static let baseHeight: CGFloat = 36
    private static let progressHeight: CGFloat = 50

    init() {
        let panelRect = NSRect(x: 0, y: 0, width: Self.minWidth, height: Self.baseHeight)

        // Create container view
        containerView = NSView(frame: panelRect)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        // Create icon view
        iconView = NSImageView(frame: NSRect(x: 12, y: 8, width: 20, height: 20))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .systemRed
        containerView.addSubview(iconView)

        // Create text label
        textLabel = NSTextField(labelWithString: "")
        textLabel.frame = NSRect(x: 38, y: 8, width: 90, height: 20)
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textLabel.textColor = NSColor.labelColor
        textLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(textLabel)

        // Create progress bar (hidden by default)
        progressBar = NSProgressIndicator(frame: NSRect(x: 12, y: 8, width: Self.minWidth - 24, height: 4))
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.isHidden = true
        containerView.addSubview(progressBar)

        super.init(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        contentView = containerView

        // Position at top-center of main screen
        positionAtTopCenter()

        // Default to recording state
        updateState(.recording)
    }

    /// Updates the panel to display the specified state
    func updateState(_ state: StatusIndicatorState) {
        // Cancel any pending auto-dismiss
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        // Update visuals based on state
        switch state {
        case .recording:
            configureRecordingState()

        case .transcribing:
            configureTranscribingState()

        case .downloading(let progress):
            configureDownloadingState(progress: progress)

        case .error(let message):
            configureErrorState(message: message)

        case .languageChanged(let mode):
            configureLanguageChangedState(mode: mode)

        case .continuousRecording(let pendingSegments):
            configureContinuousRecordingState(pendingSegments: pendingSegments)

        case .segmentDetected:
            configureSegmentDetectedState()
        }

        // Schedule auto-dismiss if needed
        if let delay = state.autoDismissDelay {
            let workItem = DispatchWorkItem { [weak self] in
                self?.close()
            }
            autoDismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    // MARK: - State Configurations

    private func configureRecordingState() {
        // Red circle icon
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemRed

        textLabel.stringValue = "Recording"
        progressBar.isHidden = true

        resizePanel(width: Self.minWidth, height: Self.baseHeight)
    }

    private func configureTranscribingState() {
        // Waveform icon
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribing")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemBlue

        textLabel.stringValue = "Transcribing..."
        progressBar.isHidden = true

        resizePanel(width: Self.minWidth + 10, height: Self.baseHeight)
    }

    private func configureDownloadingState(progress: Double) {
        // Download icon
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Downloading")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemOrange

        if progress > 0 {
            textLabel.stringValue = String(format: "Downloading: %.0f%%", progress * 100)
            progressBar.doubleValue = progress * 100
            progressBar.isIndeterminate = false
        } else {
            textLabel.stringValue = "Downloading..."
            progressBar.isIndeterminate = true
            progressBar.startAnimation(nil)
        }

        // Move text label up and show progress bar
        textLabel.frame.origin.y = 26
        iconView.frame.origin.y = 24
        progressBar.frame = NSRect(x: 12, y: 10, width: Self.maxWidth - 24, height: 6)
        progressBar.isHidden = false

        resizePanel(width: Self.maxWidth, height: Self.progressHeight)
    }

    private func configureErrorState(message: String) {
        // Error icon
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "Error")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemRed

        // Truncate message if too long
        let displayMessage = message.count > 25 ? String(message.prefix(22)) + "..." : message
        textLabel.stringValue = displayMessage
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 8
        iconView.frame.origin.y = 8

        let width = min(Self.maxWidth, Self.minWidth + CGFloat(displayMessage.count - 9) * 7)
        resizePanel(width: width, height: Self.baseHeight)
    }

    private func configureLanguageChangedState(mode: String) {
        // Globe icon
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Language")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemGreen

        textLabel.stringValue = mode
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 8
        iconView.frame.origin.y = 8

        resizePanel(width: Self.minWidth, height: Self.baseHeight)
    }

    private func configureContinuousRecordingState(pendingSegments: Int) {
        // Mic icon with continuous recording indicator
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Continuous Recording")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemBlue

        if pendingSegments > 0 {
            textLabel.stringValue = "Recording... (\(pendingSegments) pending)"
        } else {
            textLabel.stringValue = "Recording..."
        }
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 8
        iconView.frame.origin.y = 8

        let width = pendingSegments > 0 ? Self.maxWidth : Self.minWidth + 10
        resizePanel(width: width, height: Self.baseHeight)
    }

    private func configureSegmentDetectedState() {
        // Checkmark icon for segment detection
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Segment Detected")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemGreen

        textLabel.stringValue = "Segment detected"
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 8
        iconView.frame.origin.y = 8

        resizePanel(width: Self.minWidth + 20, height: Self.baseHeight)
    }

    // MARK: - Layout Helpers

    private func resizePanel(width: CGFloat, height: CGFloat) {
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y + frame.height - height,  // Keep top position stable
            width: width,
            height: height
        )
        setFrame(newFrame, display: true, animate: false)

        // Update container view
        containerView.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Update text label width
        textLabel.frame.size.width = width - 50

        // Re-center horizontally
        positionAtTopCenter()
    }

    private func positionAtTopCenter() {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    override func close() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        super.close()
    }
}
