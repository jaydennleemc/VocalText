import XCTest
@testable import Typeless

final class AppConstantsTests: XCTestCase {
    // MARK: - Audio Constants

    func testAudioDefaults() {
        XCTAssertEqual(AppConstants.Audio.defaultSampleRate, 44100)
        XCTAssertEqual(AppConstants.Audio.defaultChannels, 1)
        XCTAssertEqual(AppConstants.Audio.defaultBitDepth, 16)
        XCTAssertEqual(AppConstants.Audio.wavHeaderSize, 44)
        XCTAssertEqual(AppConstants.Audio.bufferSize, 1024)
    }

    func testAudioMaxRecordingDataSize() {
        XCTAssertEqual(AppConstants.Audio.maxRecordingDataSize, 100 * 1024 * 1024)
        XCTAssertGreaterThan(AppConstants.Audio.maxRecordingDataSize, 0)
    }

    func testAudioMinMaxDB() {
        XCTAssertLessThan(AppConstants.Audio.minDB, AppConstants.Audio.maxDB)
        XCTAssertLessThanOrEqual(AppConstants.Audio.minDB, 0)
        XCTAssertGreaterThanOrEqual(AppConstants.Audio.maxDB, -20)
    }

    // MARK: - Recording Constants

    func testRecordingDefaults() {
        XCTAssertEqual(AppConstants.Recording.minimumDuration, 0.5)
        XCTAssertGreaterThan(AppConstants.Recording.minimumDuration, 0)
        XCTAssertEqual(AppConstants.Recording.timerInterval, 0.1)
        XCTAssertEqual(AppConstants.Recording.waveformTimerInterval, 0.05)
        XCTAssertEqual(AppConstants.Recording.waveformBarCount, 50)
    }

    // MARK: - UI Constants

    func testWindowDimensions() {
        XCTAssertEqual(AppConstants.UI.windowWidth, 400)
        XCTAssertEqual(AppConstants.UI.windowHeight, 340)
        XCTAssertGreaterThan(AppConstants.UI.windowWidth, 0)
        XCTAssertGreaterThan(AppConstants.UI.windowHeight, 0)
    }

    func testSpacingProgression() {
        // Spacing should be strictly increasing
        let spacings = [
            AppConstants.UI.spacingXXS,
            AppConstants.UI.spacingXS,
            AppConstants.UI.spacingSM,
            AppConstants.UI.spacingMD,
            AppConstants.UI.spacingLG,
            AppConstants.UI.spacingXL,
        ]
        for i in 0..<spacings.count - 1 {
            XCTAssertLessThan(spacings[i], spacings[i + 1],
                "Spacing at index \(i) should be less than \(i + 1)")
        }
    }

    func testCornerRadiusProgression() {
        let radii = [
            AppConstants.UI.radiusSM,
            AppConstants.UI.radiusMD,
            AppConstants.UI.radiusLG,
            AppConstants.UI.radiusXL,
        ]
        for i in 0..<radii.count - 1 {
            XCTAssertLessThan(radii[i], radii[i + 1],
                "Radius at index \(i) should be less than \(i + 1)")
        }
    }

    func testRecordButtonSizesPositive() {
        XCTAssertGreaterThan(AppConstants.UI.recordButtonSize, 0)
        XCTAssertGreaterThan(AppConstants.UI.recordButtonRingSize, AppConstants.UI.recordButtonSize)
    }

    // MARK: - Animation Constants

    func testAnimationDurationsPositive() {
        let durations: [TimeInterval] = [
            AppConstants.Animation.waveformBarDuration,
            AppConstants.Animation.buttonPressDuration,
            AppConstants.Animation.pulseRingDuration,
            AppConstants.Animation.tutorialSpringResponse,
            AppConstants.Animation.fadeOutDuration,
            AppConstants.Animation.navigationDuration,
            AppConstants.Animation.errorBannerDuration,
            AppConstants.Animation.spinnerDuration,
            AppConstants.Animation.copiedIndicatorDuration,
        ]
        for duration in durations {
            XCTAssertGreaterThan(duration, 0, "Animation duration should be positive")
        }
    }

    func testSpringDampingInRange() {
        XCTAssertGreaterThan(AppConstants.Animation.tutorialSpringDamping, 0)
        XCTAssertLessThanOrEqual(AppConstants.Animation.tutorialSpringDamping, 1)
        XCTAssertGreaterThan(AppConstants.Animation.springDamping, 0)
        XCTAssertLessThanOrEqual(AppConstants.Animation.springDamping, 1)
    }

    // MARK: - Storage & Device Constants

    func testStorageConstants() {
        XCTAssertGreaterThan(AppConstants.Storage.requiredFreeSpaceGB, 0)
        XCTAssertGreaterThan(AppConstants.Storage.requiredMemoryGB, 0)
        XCTAssertFalse(AppConstants.Storage.modelBasePath.isEmpty)
    }

    func testDeviceLoadDelay() {
        XCTAssertGreaterThan(AppConstants.Device.deviceLoadDelay, 0)
    }

    // MARK: - Error Constants

    func testErrorDurations() {
        XCTAssertGreaterThan(AppConstants.Error.autoDismissDurationError, AppConstants.Error.autoDismissDurationWarning)
        XCTAssertGreaterThan(AppConstants.Error.autoDismissDurationWarning, AppConstants.Error.autoDismissDurationInfo)
        XCTAssertEqual(AppConstants.Error.maxConsecutiveErrors, 3)
    }

    // MARK: - Tutorial & Defaults

    func testTutorialConstants() {
        XCTAssertGreaterThanOrEqual(AppConstants.Tutorial.showDelay, 0)
    }

    func testDefaultValues() {
        XCTAssertEqual(AppConstants.Defaults.model, "tiny")
        XCTAssertFalse(AppConstants.Defaults.model.isEmpty)
        XCTAssertFalse(AppConstants.Defaults.language.isEmpty)
        XCTAssertFalse(AppConstants.Defaults.uiLanguage.isEmpty)
        XCTAssertTrue(AppConstants.Defaults.shortcutEnabled)
        XCTAssertFalse(AppConstants.Defaults.shortcutKey.isEmpty)
    }
}
