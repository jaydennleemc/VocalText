import XCTest
@testable import Typeless

final class NotificationNameTests: XCTestCase {
    // MARK: - Recording Notifications

    func testRecordingStarted() {
        let notification = Notification.Name.recordingStarted
        XCTAssertEqual(notification.rawValue, "RecordingStarted")
    }

    func testRecordingStopped() {
        let notification = Notification.Name.recordingStopped
        XCTAssertEqual(notification.rawValue, "RecordingStopped")
    }

    // MARK: - Transcription Notifications

    func testTranscribingNotifications() {
        XCTAssertEqual(Notification.Name.transcribingStarted.rawValue, "TranscribingStarted")
        XCTAssertEqual(Notification.Name.transcribingStopped.rawValue, "TranscribingStopped")
        XCTAssertEqual(Notification.Name.transcriptionError.rawValue, "TranscriptionError")
    }

    // MARK: - Model Notifications

    func testModelNotifications() {
        XCTAssertEqual(Notification.Name.modelChanged.rawValue, "ModelChanged")
        XCTAssertEqual(Notification.Name.modelDownloadRequested.rawValue, "ModelDownloadRequested")
        XCTAssertEqual(Notification.Name.modelDownloadStarted.rawValue, "ModelDownloadStarted")
        XCTAssertEqual(Notification.Name.modelDownloadFinished.rawValue, "ModelDownloadFinished")
        XCTAssertEqual(Notification.Name.modelErrorOccurred.rawValue, "ModelErrorOccurred")
    }

    // MARK: - UI Action Notifications

    func testUIActionNotifications() {
        XCTAssertEqual(Notification.Name.toggleRecording.rawValue, "ToggleRecording")
        XCTAssertEqual(Notification.Name.copyTranscript.rawValue, "CopyTranscript")
        XCTAssertEqual(Notification.Name.openSettings.rawValue, "OpenSettings")
        XCTAssertEqual(Notification.Name.closePopover.rawValue, "ClosePopover")
        XCTAssertEqual(Notification.Name.showTutorial.rawValue, "ShowTutorial")
        XCTAssertEqual(Notification.Name.forceRetryDownload.rawValue, "ForceRetryDownload")
    }

    // MARK: - Quick Record Notifications

    func testQuickRecordNotifications() {
        XCTAssertEqual(Notification.Name.startQuickRecord.rawValue, "StartQuickRecord")
        XCTAssertEqual(Notification.Name.stopQuickRecord.rawValue, "StopQuickRecord")
    }

    // MARK: - Device Notifications

    func testAudioDevicesChanged() {
        XCTAssertEqual(Notification.Name.audioDevicesChanged.rawValue, "AudioDevicesChanged")
    }

    // MARK: - Uniqueness

    func testAllNotificationNamesAreUnique() {
        let names: [Notification.Name] = [
            .recordingStarted, .recordingStopped,
            .transcribingStarted, .transcribingStopped, .transcriptionError,
            .modelChanged, .modelDownloadRequested, .modelDownloadStarted,
            .modelDownloadFinished, .modelErrorOccurred,
            .toggleRecording, .copyTranscript, .openSettings,
            .closePopover, .showTutorial, .forceRetryDownload,
            .startQuickRecord, .stopQuickRecord,
            .audioDevicesChanged,
        ]
        let rawValues = names.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueRawValues.count,
            "All notification names should be unique")
    }
}
