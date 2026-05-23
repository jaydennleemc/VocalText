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
    }

    enum Recording {
        static let minimumDuration: TimeInterval = 0.5
        static let timerInterval: TimeInterval = 0.1
        static let waveformTimerInterval: TimeInterval = 0.05
        static let waveformBarCount = 50
    }

    enum UI {
        static let windowWidth: CGFloat = 400
        static let windowHeight: CGFloat = 300
        static let tutorialHeight: CGFloat = 380
    }

    enum Storage {
        static let requiredFreeSpaceGB: Double = 2.0
        static let requiredMemoryGB: Double = 4.0
        static let modelBasePath = "huggingface/models/argmaxinc/whisperkit-coreml"
    }

    enum Device {
        static let monitoringInterval: TimeInterval = 5.0
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
        static let minimumDuration: TimeInterval = 0.5
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