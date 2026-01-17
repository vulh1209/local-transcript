import AudioToolbox
import AppKit

struct AudioFeedback {
    /// Play sound when recording starts
    static func playStartSound() {
        // System sound 1113 = "begin_record" on macOS
        // Fallback to beep if system sound doesn't work
        AudioServicesPlaySystemSound(1113)
    }

    /// Play sound when recording stops
    static func playStopSound() {
        // System sound 1114 = "end_record" on macOS
        AudioServicesPlaySystemSound(1114)
    }

    /// Fallback beep (if system sounds don't work)
    static func playBeep() {
        NSSound.beep()
    }
}
