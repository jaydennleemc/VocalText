import SwiftUI

// MARK: - Error Type

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

    var backgroundColor: Color { color.opacity(0.1) }
    var borderColor: Color { color.opacity(0.3) }
}

// MARK: - TypelessError

enum TypelessError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case networkNotConnected
    case networkTimeout
    case networkServerNotFound
    case networkGeneric(reason: String)
    case modelDownloadFailed(reason: String)
    case modelLoadFailed(reason: String)
    case audioDeviceUnavailable
    case audioEngineFailed(reason: String)
    case audioProcessingFailed(reason: String)
    case transcriptionFailed(reason: String)
    case transcriptionEmptyResult
    case fileNotFound(path: String)
    case fileEmpty(path: String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("error.audio.permissionDenied", comment: "Microphone permission denied")
        case .networkNotConnected:
            return NSLocalizedString("error.network.notConnected", comment: "No network connection")
        case .networkTimeout:
            return NSLocalizedString("error.network.timeout", comment: "Connection timeout")
        case .networkServerNotFound:
            return NSLocalizedString("error.network.serverNotFound", comment: "Server not found")
        case .networkGeneric(let reason):
            return String(format: NSLocalizedString("error.network.generic", comment: "Network error"), reason)
        case .modelDownloadFailed(let reason):
            return String(format: NSLocalizedString("model.status.download.failed", comment: "Model download failed"), reason)
        case .modelLoadFailed(let reason):
            return String(format: NSLocalizedString("model.status.load.failed", comment: "Model load failed"), reason)
        case .audioDeviceUnavailable:
            return NSLocalizedString("error.audio.noDevice", comment: "No audio device")
        case .audioEngineFailed(let reason):
            return String(format: NSLocalizedString("error.audio.engineFailed", comment: "Audio engine failed"), reason)
        case .audioProcessingFailed(let reason):
            return String(format: NSLocalizedString("error.audio.processingFailed", comment: "Audio processing failed"), reason)
        case .transcriptionFailed(let reason):
            return String(format: NSLocalizedString("error.transcription.failed", comment: "Transcription failed"), reason)
        case .transcriptionEmptyResult:
            return NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result")
        case .fileNotFound(let path):
            return String(format: NSLocalizedString("error.file.notFound", comment: "File not found"), path)
        case .fileEmpty(let path):
            return String(format: NSLocalizedString("error.file.empty", comment: "File is empty"), path)
        }
    }

    var type: ErrorType {
        switch self {
        case .networkNotConnected, .networkTimeout, .networkServerNotFound, .transcriptionEmptyResult:
            return .warning
        default:
            return .error
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied, .audioDeviceUnavailable, .fileNotFound, .fileEmpty:
            return false
        default:
            return true
        }
    }
}
