import SwiftUI
import AppKit

// MARK: - Design Tokens

enum GlassDesign {
    // MARK: - Colors
    enum Colors {
        // Glass background colors with transparency
        static let glassPrimary = Color.white.opacity(0.15)
        static let glassSecondary = Color.white.opacity(0.08)
        static let glassTertiary = Color.white.opacity(0.05)

        // Border colors
        static let glassBorder = Color.white.opacity(0.25)
        static let glassBorderSubtle = Color.white.opacity(0.12)

        // State colors (semantic)
        static let recording = Color.red
        static let transcribing = Color.blue
        static let downloading = Color.orange
        static let success = Color.green
        static let error = Color.red

        // Glow colors for states
        static let recordingGlow = Color.red.opacity(0.4)
        static let transcribingGlow = Color.blue.opacity(0.3)
        static let successGlow = Color.green.opacity(0.3)
        static let downloadingGlow = Color.orange.opacity(0.3)
        static let errorGlow = Color.red.opacity(0.3)

        // Text colors
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.secondary.opacity(0.7)
    }

    // MARK: - AppKit Colors
    enum AppKitColors {
        static let borderGradientStart = NSColor.white.withAlphaComponent(0.35)
        static let borderGradientEnd = NSColor.white.withAlphaComponent(0.1)
        static let recordingGlow = NSColor.systemRed.withAlphaComponent(0.5)
        static let transcribingGlow = NSColor.systemBlue.withAlphaComponent(0.4)
        static let successGlow = NSColor.systemGreen.withAlphaComponent(0.4)
        static let downloadingGlow = NSColor.systemOrange.withAlphaComponent(0.4)
        static let errorGlow = NSColor.systemRed.withAlphaComponent(0.5)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radii
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let card: CGFloat = 14
        static let pill: CGFloat = 22
    }

    // MARK: - Animation
    enum Animation {
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let medium = SwiftUI.Animation.easeOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}
