import AppKit

struct AudioFeedback {
    /// Play sound when recording starts
    static func playStartSound() {
        // Use macOS system sound "Morse" for start
        if let sound = NSSound(named: "Morse") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    /// Play sound when recording stops
    static func playStopSound() {
        // Use macOS system sound "Ping" for stop
        if let sound = NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
