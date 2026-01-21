import AppKit

/// A floating panel that displays status indicators for various app states.
/// Shows recording, transcribing, downloading, error, and language change states.
/// Uses glassmorphism design with blur effects and state-specific glows.
class StatusIndicatorPanel: NSPanel {
    private let visualEffectView: NSVisualEffectView
    private let containerView: NSView
    private let iconView: NSImageView
    private let textLabel: NSTextField
    private let progressBar: NSProgressIndicator
    private let closeButton: NSButton
    private let translatedTextView: NSScrollView
    private let translatedTextLabel: NSTextView
    private let borderLayer: CAGradientLayer
    private let borderMaskLayer: CAShapeLayer

    private var autoDismissWorkItem: DispatchWorkItem?
    private var pulseAnimation: CABasicAnimation?

    // Panel sizing
    private static let minWidth: CGFloat = 150
    private static let maxWidth: CGFloat = 320
    private static let baseHeight: CGFloat = 44
    private static let progressHeight: CGFloat = 58
    private static let translatedHeight: CGFloat = 120
    private static let cornerRadius: CGFloat = 22

    init() {
        let panelRect = NSRect(x: 0, y: 0, width: Self.minWidth, height: Self.baseHeight)

        // Create visual effect view for blur (key glassmorphism element)
        visualEffectView = NSVisualEffectView(frame: panelRect)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = Self.cornerRadius
        visualEffectView.layer?.masksToBounds = true

        // Create container for content
        containerView = NSView(frame: panelRect)
        containerView.wantsLayer = true

        // Create icon view with modern styling
        iconView = NSImageView(frame: NSRect(x: 14, y: 11, width: 22, height: 22))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        containerView.addSubview(iconView)

        // Create text label
        textLabel = NSTextField(labelWithString: "")
        textLabel.frame = NSRect(x: 44, y: 12, width: 100, height: 20)
        textLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        textLabel.textColor = NSColor.labelColor
        textLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(textLabel)

        // Create progress bar (hidden by default)
        progressBar = NSProgressIndicator(frame: NSRect(x: 14, y: 10, width: Self.minWidth - 28, height: 6))
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.isHidden = true
        progressBar.wantsLayer = true
        progressBar.layer?.cornerRadius = 3
        containerView.addSubview(progressBar)

        // Create close button (hidden by default)
        closeButton = NSButton(frame: NSRect(x: Self.maxWidth - 28, y: Self.translatedHeight - 28, width: 20, height: 20))
        closeButton.bezelStyle = .circular
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.isHidden = true
        containerView.addSubview(closeButton)

        // Create translated text scroll view (hidden by default)
        translatedTextView = NSScrollView(frame: NSRect(x: 12, y: 12, width: Self.maxWidth - 24, height: Self.translatedHeight - 44))
        translatedTextView.hasVerticalScroller = true
        translatedTextView.hasHorizontalScroller = false
        translatedTextView.autohidesScrollers = true
        translatedTextView.borderType = .noBorder
        translatedTextView.drawsBackground = false
        translatedTextView.isHidden = true

        // Create text view for translated content
        translatedTextLabel = NSTextView(frame: NSRect(x: 0, y: 0, width: Self.maxWidth - 24, height: Self.translatedHeight - 44))
        translatedTextLabel.isEditable = false
        translatedTextLabel.isSelectable = true
        translatedTextLabel.drawsBackground = false
        translatedTextLabel.font = NSFont.systemFont(ofSize: 13)
        translatedTextLabel.textColor = NSColor.labelColor
        translatedTextLabel.textContainerInset = NSSize(width: 0, height: 0)

        translatedTextView.documentView = translatedTextLabel
        containerView.addSubview(translatedTextView)

        // Create gradient border layer
        borderLayer = CAGradientLayer()
        borderLayer.frame = panelRect
        borderLayer.cornerRadius = Self.cornerRadius
        borderLayer.colors = [
            GlassDesign.AppKitColors.borderGradientStart.cgColor,
            GlassDesign.AppKitColors.borderGradientEnd.cgColor
        ]
        borderLayer.startPoint = CGPoint(x: 0, y: 0)
        borderLayer.endPoint = CGPoint(x: 1, y: 1)

        // Create border mask
        borderMaskLayer = CAShapeLayer()
        let maskPath = CGMutablePath()
        maskPath.addRoundedRect(
            in: panelRect.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius
        )
        borderMaskLayer.path = maskPath
        borderMaskLayer.fillColor = nil
        borderMaskLayer.strokeColor = NSColor.white.cgColor
        borderMaskLayer.lineWidth = 1.0
        borderLayer.mask = borderMaskLayer

        visualEffectView.layer?.addSublayer(borderLayer)
        visualEffectView.addSubview(containerView)

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

        contentView = visualEffectView

        // Set up close button action
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)

        // Position at top-center of main screen
        positionAtTopCenter()

        // Default to recording state
        updateState(.recording)
    }

    @objc private func closeButtonClicked() {
        close()
    }

    /// Updates the panel to display the specified state
    func updateState(_ state: StatusIndicatorState) {
        // Cancel any pending auto-dismiss
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        stopPulseAnimation()

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

        case .translating:
            configureTranslatingState()

        case .translated(let text):
            configureTranslatedState(text: text)
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

    // MARK: - Glow Effects

    private func updateGlow(color: NSColor, animated: Bool = true) {
        let duration = animated ? 0.3 : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        visualEffectView.layer?.shadowColor = color.cgColor
        visualEffectView.layer?.shadowRadius = 15
        visualEffectView.layer?.shadowOpacity = 1.0
        visualEffectView.layer?.shadowOffset = .zero
        CATransaction.commit()
    }

    private func clearGlow() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        visualEffectView.layer?.shadowOpacity = 0
        CATransaction.commit()
    }

    private func startPulseAnimation() {
        guard pulseAnimation == nil else { return }

        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.6
        pulse.toValue = 1.0
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        visualEffectView.layer?.add(pulse, forKey: "pulseGlow")
        pulseAnimation = pulse
    }

    private func stopPulseAnimation() {
        visualEffectView.layer?.removeAnimation(forKey: "pulseGlow")
        pulseAnimation = nil
    }

    // MARK: - State Configurations

    private func configureRecordingState() {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemRed

        textLabel.stringValue = "Recording"
        progressBar.isHidden = true

        // Reset text position
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.recordingGlow)
        startPulseAnimation()

        resizePanel(width: Self.minWidth, height: Self.baseHeight)
    }

    private func configureTranscribingState() {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribing")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemBlue

        textLabel.stringValue = "Transcribing..."
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.transcribingGlow)

        resizePanel(width: Self.minWidth + 15, height: Self.baseHeight)
    }

    private func configureDownloadingState(progress: Double) {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
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
        textLabel.frame.origin.y = 30
        iconView.frame.origin.y = 28
        progressBar.frame = NSRect(x: 14, y: 12, width: Self.maxWidth - 28, height: 6)
        progressBar.isHidden = false

        updateGlow(color: GlassDesign.AppKitColors.downloadingGlow)

        resizePanel(width: Self.maxWidth, height: Self.progressHeight)
    }

    private func configureErrorState(message: String) {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "Error")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemRed

        // Truncate message if too long
        let displayMessage = message.count > 25 ? String(message.prefix(22)) + "..." : message
        textLabel.stringValue = displayMessage
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.errorGlow)

        let width = min(Self.maxWidth, Self.minWidth + CGFloat(displayMessage.count - 9) * 7)
        resizePanel(width: width, height: Self.baseHeight)
    }

    private func configureLanguageChangedState(mode: String) {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Language")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemGreen

        textLabel.stringValue = mode
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.successGlow)

        resizePanel(width: Self.minWidth, height: Self.baseHeight)
    }

    private func configureContinuousRecordingState(pendingSegments: Int) {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
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
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.transcribingGlow)
        startPulseAnimation()

        let width = pendingSegments > 0 ? Self.maxWidth : Self.minWidth + 15
        resizePanel(width: width, height: Self.baseHeight)
    }

    private func configureSegmentDetectedState() {
        hideTranslationUI()

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Segment Detected")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemGreen

        textLabel.stringValue = "Segment detected"
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.successGlow)

        resizePanel(width: Self.minWidth + 30, height: Self.baseHeight)
    }

    private func configureTranslatingState() {
        hideTranslationUI()

        // Globe with ellipsis icon for translation in progress
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "globe.badge.ellipsis", accessibilityDescription: "Translating")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemBlue

        textLabel.stringValue = "Translating..."
        progressBar.isHidden = true

        // Reset positions
        textLabel.frame.origin.y = 12
        iconView.frame.origin.y = 11

        updateGlow(color: GlassDesign.AppKitColors.transcribingGlow)

        resizePanel(width: Self.minWidth + 15, height: Self.baseHeight)
    }

    private func configureTranslatedState(text: String) {
        // Checkmark icon for translation completed
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Translated")
        iconView.image = image?.withSymbolConfiguration(config)
        iconView.contentTintColor = .systemGreen

        textLabel.stringValue = "Translated (copied)"
        progressBar.isHidden = true

        // Position header elements at top
        iconView.frame.origin.y = Self.translatedHeight - 28
        textLabel.frame.origin.y = Self.translatedHeight - 28

        // Show close button
        closeButton.frame.origin = NSPoint(x: Self.maxWidth - 28, y: Self.translatedHeight - 28)
        closeButton.isHidden = false

        // Show translated text in scrollable text view
        translatedTextLabel.string = text
        translatedTextView.frame = NSRect(x: 12, y: 12, width: Self.maxWidth - 24, height: Self.translatedHeight - 48)
        translatedTextLabel.frame.size.width = Self.maxWidth - 24
        translatedTextView.isHidden = false

        updateGlow(color: GlassDesign.AppKitColors.successGlow)

        resizePanel(width: Self.maxWidth, height: Self.translatedHeight)
    }

    /// Hide translation-specific UI elements
    private func hideTranslationUI() {
        closeButton.isHidden = true
        translatedTextView.isHidden = true
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

        // Update visual effect view
        visualEffectView.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Update container view
        containerView.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Update text label width
        textLabel.frame.size.width = width - 58

        // Update border layer
        borderLayer.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let maskPath = CGMutablePath()
        maskPath.addRoundedRect(
            in: NSRect(x: 0, y: 0, width: width, height: height).insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius
        )
        borderMaskLayer.path = maskPath

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
        stopPulseAnimation()
        clearGlow()
        super.close()
    }
}
