import Foundation
import CoreGraphics

// MARK: - App Constants

enum AppConstants {
    enum Audio {
        static let defaultSampleRate: Double = 44100
        static let defaultChannels: UInt16 = 1
        static let defaultBitDepth: UInt16 = 16
        static let wavHeaderSize = 44
        static let minDB: Double = -80.0
        static let maxDB: Double = -10.0
        static let bufferSize: UInt32 = 1024
        static let maxRecordingDataSize: Int = 100 * 1024 * 1024 // 100MB cap for safety
    }

    enum Recording {
        static let minimumDuration: TimeInterval = 0.5
        static let timerInterval: TimeInterval = 0.1
        static let waveformTimerInterval: TimeInterval = 0.05
        static let waveformBarCount = 50
    }

    // MARK: - UI Design System

    enum UI {
        // Window dimensions
        static let windowWidth: CGFloat = 400
        static let windowHeight: CGFloat = 340
        static let tutorialHeight: CGFloat = 380
        static let settingsHeight: CGFloat = 340

        // Spacing
        static let spacingXXS: CGFloat = 4
        static let spacingXS: CGFloat = 8
        static let spacingSM: CGFloat = 12
        static let spacingMD: CGFloat = 16
        static let spacingLG: CGFloat = 20
        static let spacingXL: CGFloat = 24

        // Corner radius
        static let radiusSM: CGFloat = 6
        static let radiusMD: CGFloat = 10
        static let radiusLG: CGFloat = 14
        static let radiusXL: CGFloat = 20

        // Typography sizes
        static let fontCaption: CGFloat = 11
        static let fontBody: CGFloat = 13
        static let fontBodyLarge: CGFloat = 14
        static let fontCardTitle: CGFloat = 12
        static let fontSectionTitle: CGFloat = 14
        static let fontHeader: CGFloat = 16
        static let fontTitle: CGFloat = 18
        static let fontTimer: CGFloat = 28

        // Icon sizes
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 18
        static let iconLarge: CGFloat = 24
        static let iconXL: CGFloat = 36

        // Component sizes
        static let recordButtonSize: CGFloat = 56
        static let recordButtonRingSize: CGFloat = 64
        static let headerIconSize: CGFloat = 22
        static let headerIconRadius: CGFloat = 6
        static let headerButtonSize: CGFloat = 30
        static let stateIconSize: CGFloat = 56
        static let stateIconRadius: CGFloat = 16
        static let tutorialIconSize: CGFloat = 90
        static let waveformBarWidth: CGFloat = 4
        static let waveformHeight: CGFloat = 70
        static let transcriptMaxHeight: CGFloat = 120
        static let settingCardIconSize: CGFloat = 26
        static let settingCardIconRadius: CGFloat = 7
        static let radioButtonSize: CGFloat = 18
        static let radioInnerSize: CGFloat = 10
        static let stepDotSize: CGFloat = 7
        static let stepDotActiveWidth: CGFloat = 20
        static let progressBarHeight: CGFloat = 3
        static let overlayWidth: CGFloat = 360
        static let overlayMinHeight: CGFloat = 52
        static let overlayMaxWidth: CGFloat = 500
        static let overlayCornerRadius: CGFloat = 10
        static let overlayMarginFromCursor: CGFloat = 24
        static let settingsIconSize: CGFloat = 26
    }

    // MARK: - Animation

    enum Animation {
        static let waveformBarDuration: Double = 0.15
        static let buttonPressDuration: Double = 0.1
        static let pulseRingDuration: Double = 1.0
        static let tutorialSpringResponse: Double = 0.4
        static let tutorialSpringDamping: Double = 0.85
        static let tutorialIconSpringResponse: Double = 0.5
        static let tutorialIconSpringDamping: Double = 0.6
        static let settingsSpringResponse: Double = 0.3
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.85
        static let fadeOutDuration: Double = 0.2
        static let navigationDuration: Double = 0.2
        static let errorBannerDuration: Double = 0.3
        static let overlayHideDelay: Double = 1.5
        static let spinnerDuration: Double = 1.0
        static let copiedIndicatorDuration: Double = 2.0
    }

    // MARK: - Colors (hex values for reference)

    enum Colors {
        static let bgPrimary = "#0f0f11"
        static let bgSecondary = "#1a1a1e"
        static let bgCard = "#222226"
        static let bgHover = "#2a2a2f"
        static let border = "#2e2e34"
        static let borderActive = "#5e5ce6"
        static let textPrimary = "#f5f5f7"
        static let textSecondary = "#98989f"
        static let textTertiary = "#63636b"
        static let accent = "#5e5ce6"
        static let accentHover = "#6b69f0"
        static let red = "#ff453a"
        static let green = "#30d158"
        static let orange = "#ff9f0a"
        static let purple = "#bf5af2"
    }

    // MARK: - Legacy constants

    enum Storage {
        static let requiredFreeSpaceGB: Double = 2.0
        static let requiredMemoryGB: Double = 4.0
        static let modelBasePath = "huggingface/models/argmaxinc/whisperkit-coreml"
    }

    enum Device {
        static let deviceLoadDelay: TimeInterval = 0.5
    }

    enum Error {
        static let autoDismissDurationError: TimeInterval = 5.0
        static let autoDismissDurationWarning: TimeInterval = 3.0
        static let autoDismissDurationInfo: TimeInterval = 2.0
        static let maxConsecutiveErrors = 3
    }

    enum Network {
        static let timeoutInterval: TimeInterval = 3.0
        static let appleConnectivityURL = "https://www.apple.com"
    }

    enum Memory {
        static let monitoringInterval: TimeInterval = 5.0
        static let warningThresholdMB: Double = 100.0
    }

    enum Tutorial {
        static let showDelay: TimeInterval = 0.1
    }

    enum QuickRecord {
        static let copiedIndicatorDuration: TimeInterval = 2.0
    }

    enum Transcription {
        static let temperature: Float = 0.0
        static let sampleLength: Int = 224
    }

    enum Defaults {
        static let model = "tiny"
        static let language = "zh"
        static let uiLanguage = "en"
        static let shortcutEnabled = true
        static let shortcutKey = "cmd+shift+v"
    }
}