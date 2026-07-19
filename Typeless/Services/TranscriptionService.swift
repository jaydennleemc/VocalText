import Foundation
import WhisperKit

// MARK: - Transcription Service

@MainActor
final class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    @Published var hasValidTranscript = false

    private var selectedLanguage: String = AppConstants.Defaults.language

    // MARK: - Language

    func setLanguage(_ language: String) {
        selectedLanguage = language
    }

    var currentLanguage: String { selectedLanguage }

    // MARK: - Transcription

    func transcribe(audioFilePath: String, using whisperKit: WhisperKit?) async {
        guard let whisperKit = whisperKit else {
            transcript = NSLocalizedString("model.status.load.failed", comment: "Model failed to load")
            hasValidTranscript = false
            NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.modelLoadFailed(reason: "WhisperKit not initialized"))
            return
        }

        // Validate file
        guard FileManager.default.fileExists(atPath: audioFilePath) else {
            transcript = NSLocalizedString("error.file.notFound", comment: "Audio file not found")
            hasValidTranscript = false
            NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.fileNotFound(path: audioFilePath))
            return
        }

        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioFilePath)
            if let fileSize = fileAttributes[.size] as? NSNumber, fileSize.intValue == 0 {
                transcript = NSLocalizedString("error.file.empty", comment: "Audio file is empty")
                hasValidTranscript = false
                NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.fileEmpty(path: audioFilePath))
                return
            }
        } catch {
            #if DEBUG
            print("❌ Failed to get file info: \(error)")
            #endif
        }

        isTranscribing = true
        NotificationCenter.default.post(name: .transcribingStarted, object: nil)

        do {
            let decodingOptions = DecodingOptions(
                language: selectedLanguage,
                temperature: AppConstants.Transcription.temperature,
                sampleLength: AppConstants.Transcription.sampleLength
            )

            let result = try await whisperKit.transcribe(
                audioPath: audioFilePath,
                decodeOptions: decodingOptions
            )

            let extractedText = Self.extractTranscriptText(from: result)
            transcript = extractedText
            hasValidTranscript = !extractedText.isEmpty
        } catch {
            transcript = String(format: NSLocalizedString("error.transcription.failed", comment: "Transcription failed"), error.localizedDescription)
            hasValidTranscript = false
            NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.transcriptionFailed(reason: error.localizedDescription))
        }

        isTranscribing = false
        NotificationCenter.default.post(name: .transcribingStopped, object: nil)
    }

    func resetTranscript() {
        transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
        hasValidTranscript = false
    }

    private static func extractTranscriptText(from result: Any) -> String {
        // Primary expected type from WhisperKit
        if let results = result as? [TranscriptionResult] {
            return results.first?.text ?? ""
        }

        // Fallback for string array results
        if let textResults = result as? [String] {
            return textResults.first ?? ""
        }

        // Single string result
        if let singleText = result as? String {
            return singleText
        }

        #if DEBUG
        print("⚠️ Unexpected WhisperKit result type: \(type(of: result))")
        #endif
        return ""
    }
}

// MARK: - Notification Names
// Notification.Name extensions are defined in Extensions/Notifications.swift