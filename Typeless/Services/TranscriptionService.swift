import Foundation
import WhisperKit

// MARK: - Transcription Service

@MainActor
final class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    @Published var hasValidTranscript = false

    private var selectedLanguage = "zh"
    private var activeTask: Task<String, Error>?

    func setLanguage(_ language: String) {
        selectedLanguage = language
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        isTranscribing = false
    }

    func transcribe(audioFilePath: String, using whisperKit: WhisperKit?) async -> String {
        if let activeTask {
            activeTask.cancel()
            _ = try? await activeTask.value
            self.activeTask = nil
        }

        guard let whisperKit else {
            transcript = NSLocalizedString("model.status.load.failed", comment: "")
            hasValidTranscript = false
            return ""
        }

        guard FileManager.default.fileExists(atPath: audioFilePath) else {
            hasValidTranscript = false
            return ""
        }

        isTranscribing = true
        hasValidTranscript = false

        let language = Self.normalizeLanguageCode(selectedLanguage)

        // Pass 1: user language, no VAD (short dictation — VAD was wiping short clips).
        var text = await runTranscribe(
            whisperKit: whisperKit,
            path: audioFilePath,
            language: language,
            detectLanguage: false
        )

        // Pass 2: if empty, auto-detect language (wrong zh/yue often yields blank).
        if text.isEmpty {
            #if DEBUG
            print("⚠️ Empty with language=\(language), retry detectLanguage")
            #endif
            text = await runTranscribe(
                whisperKit: whisperKit,
                path: audioFilePath,
                language: nil,
                detectLanguage: true
            )
        }

        text = Self.cleanupTranscript(text)
        transcript = text.isEmpty
            ? NSLocalizedString("error.transcription.emptyResult", comment: "")
            : text
        hasValidTranscript = !text.isEmpty
        isTranscribing = false

        #if DEBUG
        print("✅ Transcript (\(text.count) chars): \(text.prefix(120))")
        #endif
        return text
    }

    private func runTranscribe(
        whisperKit: WhisperKit,
        path: String,
        language: String?,
        detectLanguage: Bool
    ) async -> String {
        let task = Task<String, Error> {
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: language,
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 5,
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: language != nil,
                usePrefillCache: true,
                detectLanguage: detectLanguage,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                wordTimestamps: false,
                suppressBlank: true,
                // More permissive — short BT clips were rejected as "no speech".
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.2,
                firstTokenLogProbThreshold: -1.8,
                noSpeechThreshold: 0.35,
                chunkingStrategy: .none
            )
            let result = try await whisperKit.transcribe(audioPath: path, decodeOptions: options)
            return result.map(\.text).joined(separator: " ")
        }
        activeTask = task
        do {
            return try await task.value
        } catch {
            #if DEBUG
            print("❌ transcribe pass error: \(error)")
            #endif
            return ""
        }
    }

    private static func normalizeLanguageCode(_ code: String) -> String {
        switch code.lowercased() {
        case "yue", "zh-yue", "cantonese": return "yue"
        case "zh-hans", "zh-hant", "zh-cn", "zh-tw", "chinese": return "zh"
        default: return code.lowercased()
        }
    }

    private static func cleanupTranscript(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for j in ["<|startoftranscript|>", "<|endoftext|>", "<|notimestamps|>", "[BLANK_AUDIO]", "(blank)"] {
            text = text.replacingOccurrences(of: j, with: "", options: .caseInsensitive)
        }
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = text.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || (0x4E00...0x9FFF).contains($0.value)
        }
        if letters.isEmpty { return "" }
        return text
    }
}
