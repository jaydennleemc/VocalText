import Foundation

struct RecordingEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let transcript: String
    let language: String
    let model: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        transcript: String,
        language: String,
        model: String
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.transcript = transcript
        self.language = language
        self.model = model
    }

    var preview: String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80)) + "…"
    }
}
