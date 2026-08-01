import Foundation

// MARK: - App-Wide Notification Names

extension Notification.Name {
    /// Model download/load failures (object: TypelessError)
    static let modelErrorOccurred = Notification.Name("ModelErrorOccurred")
    /// Transcription failures (object: TypelessError)
    static let transcriptionError = Notification.Name("TranscriptionError")
}
