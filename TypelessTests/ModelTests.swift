import XCTest
@testable import Typeless

final class AudioDeviceModelTests: XCTestCase {
    func testInitWithDefaults() throws {
        let device = AudioDeviceModel(id: 0, name: "Built-in Microphone")
        XCTAssertEqual(device.id, 0)
        XCTAssertEqual(device.name, "Built-in Microphone")
        XCTAssertEqual(device.uniqueID, "", "uniqueID should default to empty string")
    }

    func testInitWithAllProperties() throws {
        let device = AudioDeviceModel(id: 123, name: "External Mic", uniqueID: "USB_MIC_001")
        XCTAssertEqual(device.id, 123)
        XCTAssertEqual(device.name, "External Mic")
        XCTAssertEqual(device.uniqueID, "USB_MIC_001")
    }

    func testEqualitySameDevice() throws {
        let device1 = AudioDeviceModel(id: 1, name: "Same Device")
        let device2 = AudioDeviceModel(id: 1, name: "Same Device")
        XCTAssertEqual(device1, device2)
    }

    func testEqualityDifferentID() throws {
        let device1 = AudioDeviceModel(id: 1, name: "Device")
        let device2 = AudioDeviceModel(id: 2, name: "Device")
        XCTAssertNotEqual(device1, device2)
    }

    func testEqualityDifferentName() throws {
        let device1 = AudioDeviceModel(id: 1, name: "Device A")
        let device2 = AudioDeviceModel(id: 1, name: "Device B")
        XCTAssertNotEqual(device1, device2)
    }

    func testUniqueIDNotUsedInEquality() throws {
        let device1 = AudioDeviceModel(id: 1, name: "Mic", uniqueID: "ABC")
        let device2 = AudioDeviceModel(id: 1, name: "Mic", uniqueID: "XYZ")
        XCTAssertEqual(device1, device2, "Equality should not depend on uniqueID")
    }
}

final class TypelessErrorTests: XCTestCase {
    func testMicrophonePermissionDenied() throws {
        let error = TypelessError.microphonePermissionDenied
        XCTAssertEqual(error.errorDescription, NSLocalizedString("error.audio.permissionDenied", comment: ""))
    }

    func testErrorEquality() throws {
        let error1 = TypelessError.microphonePermissionDenied
        let error2 = TypelessError.microphonePermissionDenied
        XCTAssertEqual(error1, error2)
    }

    func testErrorInequality() throws {
        let error1 = TypelessError.microphonePermissionDenied
        let error2 = TypelessError.modelDownloadFailed(reason: "Network error")
        XCTAssertNotEqual(error1, error2)
    }

    func testModelDownloadFailed() throws {
        let reason = "Connection timeout"
        let error = TypelessError.modelDownloadFailed(reason: reason)
        let expected = String(format: NSLocalizedString("model.status.download.failed", comment: ""), reason)
        XCTAssertEqual(error.errorDescription, expected)
    }

    func testTranscriptionFailed() throws {
        let reason = "No audio data"
        let error = TypelessError.transcriptionFailed(reason: reason)
        let expected = String(format: NSLocalizedString("error.transcription.failed", comment: ""), reason)
        XCTAssertEqual(error.errorDescription, expected)
    }

    func testModelLoadFailed() throws {
        let reason = "Corrupted model file"
        let error = TypelessError.modelLoadFailed(reason: reason)
        let expected = String(format: NSLocalizedString("model.status.load.failed", comment: ""), reason)
        XCTAssertEqual(error.errorDescription, expected)
    }

    func testAudioDeviceUnavailable() throws {
        let error = TypelessError.audioDeviceUnavailable
        XCTAssertEqual(error.errorDescription, NSLocalizedString("error.audio.noDevice", comment: ""))
    }

    func testNetworkError() throws {
        let error = TypelessError.networkNotConnected
        XCTAssertEqual(error.errorDescription, NSLocalizedString("error.network.notConnected", comment: ""))
    }
}

final class RecordingEntryTests: XCTestCase {
    func testRecordingEntryInit() throws {
        let entry = RecordingEntry(
            duration: 10.0,
            transcript: "Hello world",
            language: "en",
            model: "tiny"
        )
        XCTAssertEqual(entry.transcript, "Hello world")
        XCTAssertEqual(entry.language, "en")
        XCTAssertEqual(entry.model, "tiny")
        XCTAssertEqual(entry.duration, 10.0, accuracy: 0.001)
    }

    func testRecordingEntryDate() throws {
        let before = Date()
        let entry = RecordingEntry(
            duration: 5.0,
            transcript: "Test",
            language: "en",
            model: "base"
        )
        let after = Date()
        XCTAssertGreaterThanOrEqual(entry.date, before)
        XCTAssertLessThanOrEqual(entry.date, after)
    }

    func testRecordingEntryTimestamp() throws {
        let entry = RecordingEntry(
            duration: 3.0,
            transcript: "Test",
            language: "en",
            model: "small"
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let formatted = dateFormatter.string(from: entry.date)
        XCTAssertFalse(formatted.isEmpty)
    }

    func testRecordingEntryUniqueID() throws {
        let entry1 = RecordingEntry(
            duration: 1.0,
            transcript: "First",
            language: "en",
            model: "tiny"
        )
        let entry2 = RecordingEntry(
            duration: 2.0,
            transcript: "Second",
            language: "en",
            model: "tiny"
        )
        XCTAssertNotEqual(entry1.id, entry2.id)
    }
}
