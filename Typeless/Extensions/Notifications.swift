import Foundation

// MARK: - App-Wide Notification Names

extension Notification.Name {
    // Recording
    static let recordingStarted = Notification.Name("RecordingStarted")
    static let recordingStopped = Notification.Name("RecordingStopped")

    // Transcription
    static let transcribingStarted = Notification.Name("TranscribingStarted")
    static let transcribingStopped = Notification.Name("TranscribingStopped")
    static let transcriptionError = Notification.Name("TranscriptionError")

    // Model
    static let modelChanged = Notification.Name("ModelChanged")
    static let modelDownloadRequested = Notification.Name("ModelDownloadRequested")
    static let modelDownloadStarted = Notification.Name("ModelDownloadStarted")
    static let modelDownloadFinished = Notification.Name("ModelDownloadFinished")
    static let modelErrorOccurred = Notification.Name("ModelErrorOccurred")

    // UI Actions (MenuBarController → MainView)
    static let toggleRecording = Notification.Name("ToggleRecording")
    static let copyTranscript = Notification.Name("CopyTranscript")
    static let openSettings = Notification.Name("OpenSettings")
    static let closePopover = Notification.Name("ClosePopover")
    static let showTutorial = Notification.Name("ShowTutorial")
    static let forceRetryDownload = Notification.Name("ForceRetryDownload")

    // Quick Record
    static let startQuickRecord = Notification.Name("StartQuickRecord")
    static let stopQuickRecord = Notification.Name("StopQuickRecord")

    // Devices
    static let audioDevicesChanged = Notification.Name("AudioDevicesChanged")
}
