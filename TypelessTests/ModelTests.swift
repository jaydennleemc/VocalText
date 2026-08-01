import XCTest
@testable import Typeless

final class AudioDeviceModelTests: XCTestCase {
    func testInit() throws {
        let device = AudioDeviceModel(id: "built-in", name: "Built-in Microphone")
        XCTAssertEqual(device.id, "built-in")
        XCTAssertEqual(device.name, "Built-in Microphone")
    }

    func testEquality() throws {
        let a = AudioDeviceModel(id: "1", name: "Mic")
        let b = AudioDeviceModel(id: "1", name: "Mic")
        let c = AudioDeviceModel(id: "2", name: "Mic")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

final class TypelessErrorTests: XCTestCase {
    func testMicrophonePermissionDenied() throws {
        let error = TypelessError.microphonePermissionDenied
        XCTAssertEqual(error.errorDescription, NSLocalizedString("error.audio.permissionDenied", comment: ""))
        XCTAssertFalse(error.isRecoverable)
    }

    func testErrorEquality() throws {
        XCTAssertEqual(TypelessError.microphonePermissionDenied, .microphonePermissionDenied)
        XCTAssertNotEqual(TypelessError.microphonePermissionDenied, .audioDeviceUnavailable)
    }

    func testModelDownloadFailed() throws {
        let reason = "Connection timeout"
        let error = TypelessError.modelDownloadFailed(reason: reason)
        let expected = String(format: NSLocalizedString("model.status.download.failed", comment: ""), reason)
        XCTAssertEqual(error.errorDescription, expected)
        XCTAssertTrue(error.isRecoverable)
    }
}
