import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var text: String
    var timestamp: Date
    var languageMode: String
    var duration: TimeInterval  // Recording duration in seconds

    init(text: String, languageMode: String, duration: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.languageMode = languageMode
        self.duration = duration
    }
}
