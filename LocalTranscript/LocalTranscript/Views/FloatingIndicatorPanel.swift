import AppKit

class FloatingIndicatorPanel: NSPanel {
    init() {
        let panelRect = NSRect(x: 0, y: 0, width: 120, height: 36)
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

        // Use pure AppKit view instead of SwiftUI to avoid constraint issues
        let containerView = NSView(frame: panelRect)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        // Red dot
        let dotView = NSView(frame: NSRect(x: 16, y: 12, width: 12, height: 12))
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 6
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        containerView.addSubview(dotView)

        // "Recording" label
        let label = NSTextField(labelWithString: "Recording")
        label.frame = NSRect(x: 36, y: 8, width: 70, height: 20)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor.labelColor
        containerView.addSubview(label)

        contentView = containerView

        // Position at top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
