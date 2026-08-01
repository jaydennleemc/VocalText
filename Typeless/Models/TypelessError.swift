import Foundation

// MARK: - TypelessError

enum TypelessError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case modelDownloadFailed(reason: String)
    case modelLoadFailed(reason: String)
    case audioDeviceUnavailable
    case audioEngineFailed(reason: String)
    case audioProcessingFailed(reason: String)
    case transcriptionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("error.audio.permissionDenied", comment: "Microphone permission denied")
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
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied, .audioDeviceUnavailable:
            return false
        default:
            return true
        }
    }
}
