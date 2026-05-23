import Foundation

// MARK: - Recording Entry Model

struct RecordingEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let transcript: String
    let language: String
    let model: String

    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval, transcript: String, language: String, model: String) {
        self.id = id
        self.date = date
        self.duration = duration
        self.transcript = transcript
        self.language = language
        self.model = model
    }
}