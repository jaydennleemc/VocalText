import SwiftUI

// MARK: - Error Type System

enum ErrorType {
    case warning
    case error
    case info

    var color: Color {
        switch self {
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .warning: return .orange.opacity(0.1)
        case .error: return .red.opacity(0.1)
        case .info: return .blue.opacity(0.1)
        }
    }

    var borderColor: Color {
        switch self {
        case .warning: return .orange.opacity(0.3)
        case .error: return .red.opacity(0.3)
        case .info: return .blue.opacity(0.3)
        }
    }
}

// MARK: - TypelessError Enum

enum TypelessError: LocalizedError, Equatable {
    // Microphone permissions
    case microphonePermissionDenied
    case microphonePermissionRestricted

    // Network
    case networkNotConnected
    case networkTimeout
    case networkServerNotFound
    case networkGeneric(underlying: Error)

    // Model
    case modelDownloadFailed(reason: String)
    case modelLoadFailed(reason: String)
    case modelNotFound(model: String)

    // Recording
    case audioDeviceUnavailable
    case audioEngineFailed(reason: String)
    case audioRecordingFailed(reason: String)
    case audioProcessingFailed(reason: String)

    // Transcription
    case transcriptionFailed(reason: String)
    case transcriptionEmptyResult
    case transcriptionInvalidFormat

    // File
    case fileNotFound(path: String)
    case fileEmpty(path: String)
    case fileWriteFailed(reason: String)

    // General
    case invalidState(description: String)
    case unknownError

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("error.audio.permissionDenied", comment: "Microphone permission denied")
        case .microphonePermissionRestricted:
            return NSLocalizedString("error.audio.permissionRestricted", comment: "Microphone permission restricted")
        case .networkNotConnected:
            return NSLocalizedString("error.network.notConnected", comment: "No network connection")
        case .networkTimeout:
            return NSLocalizedString("error.network.timeout", comment: "Connection timeout")
        case .networkServerNotFound:
            return NSLocalizedString("error.network.serverNotFound", comment: "Server not found")
        case .networkGeneric(let underlying):
            return String(format: NSLocalizedString("error.network.generic", comment: "Network error"), underlying.localizedDescription)
        case .modelDownloadFailed(let reason):
            return String(format: NSLocalizedString("model.status.download.failed", comment: "Model download failed"), reason)
        case .modelLoadFailed(let reason):
            return String(format: NSLocalizedString("model.status.load.failed", comment: "Model load failed"), reason)
        case .modelNotFound(let model):
            return String(format: NSLocalizedString("error.model.notFound", comment: "Model not found"), model)
        case .audioDeviceUnavailable:
            return NSLocalizedString("error.audio.noDevice", comment: "No audio device")
        case .audioEngineFailed(let reason):
            return String(format: NSLocalizedString("error.audio.engineFailed", comment: "Audio engine failed"), reason)
        case .audioRecordingFailed(let reason):
            return String(format: NSLocalizedString("error.recording.failed", comment: "Recording failed"), reason)
        case .audioProcessingFailed(let reason):
            return String(format: NSLocalizedString("error.audio.processingFailed", comment: "Audio processing failed"), reason)
        case .transcriptionFailed(let reason):
            return String(format: NSLocalizedString("error.transcription.failed", comment: "Transcription failed"), reason)
        case .transcriptionEmptyResult:
            return NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result")
        case .transcriptionInvalidFormat:
            return NSLocalizedString("error.transcription.invalidFormat", comment: "Invalid transcription format")
        case .fileNotFound(let path):
            return String(format: NSLocalizedString("error.file.notFound", comment: "File not found"), path)
        case .fileEmpty(let path):
            return String(format: NSLocalizedString("error.file.empty", comment: "File is empty"), path)
        case .fileWriteFailed(let reason):
            return String(format: NSLocalizedString("error.file.writeFailed", comment: "File write failed"), reason)
        case .invalidState(let description):
            return String(format: NSLocalizedString("error.generic.invalidState", comment: "Invalid state"), description)
        case .unknownError:
            return NSLocalizedString("error.generic.unknown", comment: "Unknown error")
        }
    }

    // MARK: - Error Level

    var type: ErrorType {
        switch self {
        case .microphonePermissionDenied, .microphonePermissionRestricted, .audioDeviceUnavailable, .invalidState:
            return .error
        case .networkNotConnected, .networkTimeout, .networkServerNotFound, .modelNotFound, .transcriptionEmptyResult:
            return .warning
        case .networkGeneric, .modelDownloadFailed, .modelLoadFailed, .audioEngineFailed,
             .audioRecordingFailed, .audioProcessingFailed, .transcriptionFailed,
             .transcriptionInvalidFormat, .fileNotFound, .fileEmpty, .fileWriteFailed, .unknownError:
            return .error
        }
    }

    // MARK: - Recoverability

    var isRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied, .microphonePermissionRestricted, .audioDeviceUnavailable:
            return false
        case .fileNotFound, .fileEmpty, .fileWriteFailed:
            return false
        case .networkNotConnected, .networkTimeout, .networkServerNotFound, .networkGeneric:
            return true
        case .modelDownloadFailed, .modelLoadFailed, .modelNotFound:
            return true
        case .audioEngineFailed, .audioRecordingFailed, .audioProcessingFailed:
            return true
        case .transcriptionFailed, .transcriptionEmptyResult, .transcriptionInvalidFormat:
            return true
        case .invalidState, .unknownError:
            return true
        }
    }

    // MARK: - Suggested Action

    var suggestedAction: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("action.requestPermission", comment: "Request permission")
        case .microphonePermissionRestricted:
            return NSLocalizedString("action.openSettings", comment: "Open system settings")
        case .networkNotConnected:
            return NSLocalizedString("action.checkConnection", comment: "Check network connection")
        case .audioDeviceUnavailable:
            return NSLocalizedString("action.connectDevice", comment: "Connect audio device")
        case .modelDownloadFailed, .modelLoadFailed, .modelNotFound:
            return NSLocalizedString("action.retryDownload", comment: "Retry download")
        default:
            return NSLocalizedString("action.retry", comment: "Retry")
        }
    }

    // MARK: - Equatable (auto-synthesized for most cases)
    // .networkGeneric uses underlying Error which doesn't conform to Equatable,
    // so we handle it manually. All other cases are auto-synthesized.

    static func == (lhs: TypelessError, rhs: TypelessError) -> Bool {
        switch (lhs, rhs) {
        case (.networkGeneric, .networkGeneric):
            return true // Compare by type only for network errors
        case (.modelDownloadFailed(let a), .modelDownloadFailed(let b)): return a == b
        case (.modelLoadFailed(let a), .modelLoadFailed(let b)): return a == b
        case (.modelNotFound(let a), .modelNotFound(let b)): return a == b
        case (.audioEngineFailed(let a), .audioEngineFailed(let b)): return a == b
        case (.audioRecordingFailed(let a), .audioRecordingFailed(let b)): return a == b
        case (.audioProcessingFailed(let a), .audioProcessingFailed(let b)): return a == b
        case (.transcriptionFailed(let a), .transcriptionFailed(let b)): return a == b
        case (.fileNotFound(let a), .fileNotFound(let b)): return a == b
        case (.fileEmpty(let a), .fileEmpty(let b)): return a == b
        case (.fileWriteFailed(let a), .fileWriteFailed(let b)): return a == b
        case (.invalidState(let a), .invalidState(let b)): return a == b
        case (.microphonePermissionDenied, .microphonePermissionDenied): return true
        case (.microphonePermissionRestricted, .microphonePermissionRestricted): return true
        case (.networkNotConnected, .networkNotConnected): return true
        case (.networkTimeout, .networkTimeout): return true
        case (.networkServerNotFound, .networkServerNotFound): return true
        case (.audioDeviceUnavailable, .audioDeviceUnavailable): return true
        case (.transcriptionEmptyResult, .transcriptionEmptyResult): return true
        case (.transcriptionInvalidFormat, .transcriptionInvalidFormat): return true
        case (.unknownError, .unknownError): return true
        default: return false
        }
    }
}