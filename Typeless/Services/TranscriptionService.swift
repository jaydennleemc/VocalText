import Foundation
import WhisperKit

// MARK: - Transcription Service

@MainActor
final class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")

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
            NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.modelLoadFailed(reason: "WhisperKit not initialized"))
            return
        }

        // Validate file
        guard FileManager.default.fileExists(atPath: audioFilePath) else {
            transcript = NSLocalizedString("error.file.notFound", comment: "Audio file not found")
            NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.fileNotFound(path: audioFilePath))
            return
        }

        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioFilePath)
            if let fileSize = fileAttributes[.size] as? NSNumber, fileSize.intValue == 0 {
                transcript = NSLocalizedString("error.file.empty", comment: "Audio file is empty")
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

            var extractedText = NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result")

            if let results = result as? [TranscriptionResult] {
                extractedText = results.first?.text ?? extractedText
            } else if let textResults = result as? [String] {
                extractedText = textResults.first?.isEmpty == false ? textResults.first! : extractedText
            } else if let singleText = result as? String {
                extractedText = singleText.isEmpty ? extractedText : singleText
            } else if let text = (result as? NSObject)?.value(forKey: "text") as? String {
                extractedText = text.isEmpty ? extractedText : text
            }

            transcript = extractedText
        } catch {
            transcript = String(format: NSLocalizedString("error.transcription.failed", comment: "Transcription failed"), error.localizedDescription)
            NotificationCenter.default.post(name: .transcriptionError, object: TypelessError.transcriptionFailed(reason: error.localizedDescription))
        }

        isTranscribing = false
        NotificationCenter.default.post(name: .transcribingStopped, object: nil)
    }

    func resetTranscript() {
        transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    }
}

// MARK: - Notification Names

// Notification names are defined in MainView.swift