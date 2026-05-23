import Foundation
import WhisperKit

// MARK: - Model Manager

@MainActor
final class ModelManager: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = ""
    @Published var isModelDownloaded = false

    private var currentModel: String = AppConstants.Defaults.model
    private var whisperKit: WhisperKit?
    private var isPreloading = false

    // MARK: - Model Management

    func setModel(_ model: String) {
        currentModel = model.lowercased()
    }

    var modelName: String { currentModel }

    func isModelAlreadyDownloaded(model: String? = nil) -> Bool {
        let modelName = (model ?? currentModel).lowercased()
        let modelPath = getModelPath(for: modelName)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: modelPath) else { return false }

        // Verify required files exist
        let requiredFiles = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "Config.json"]
        for file in requiredFiles {
            let filePath = "\(modelPath)/\(file)"
            if !fileManager.fileExists(atPath: filePath) {
                return false
            }
        }

        return true
    }

    func checkAndDownloadModelIfNeeded() async -> Bool {
        if isModelAlreadyDownloaded() {
            isModelDownloaded = true
            return true
        }

        do {
            isDownloading = true
            downloadStatus = String(format: NSLocalizedString("model.status.checking", comment: "Checking model"), currentModel)
            downloadProgress = 0.0

            NotificationCenter.default.post(name: .modelDownloadStarted, object: nil)

            let progressHandler: (Progress) -> Void = { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress.fractionCompleted
                    self?.downloadStatus = String(
                        format: NSLocalizedString("model.status.downloading", comment: "Downloading model"),
                        self?.currentModel ?? "",
                        progress.fractionCompleted * 100
                    )
                }
            }

            _ = try await WhisperKit.download(
                variant: currentModel,
                progressCallback: progressHandler
            )

            isDownloading = false
            downloadStatus = NSLocalizedString("model.status.downloaded", comment: "Model downloaded successfully")
            isModelDownloaded = true

            NotificationCenter.default.post(name: .modelDownloadFinished, object: nil)
            return true
        } catch {
            isDownloading = false
            isModelDownloaded = false

            let nsError = error as NSError
            let typelessError: TypelessError

            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    downloadStatus = NSLocalizedString("error.network.notConnected", comment: "No internet connection")
                    typelessError = .networkNotConnected
                case NSURLErrorTimedOut:
                    downloadStatus = NSLocalizedString("error.network.timeout", comment: "Connection timeout")
                    typelessError = .networkTimeout
                case NSURLErrorCannotFindHost:
                    downloadStatus = NSLocalizedString("error.network.serverNotFound", comment: "Server not found")
                    typelessError = .networkServerNotFound
                default:
                    downloadStatus = String(format: NSLocalizedString("error.network.generic", comment: "Network error"), nsError.localizedDescription)
                    typelessError = .networkGeneric(underlying: nsError)
                }
            } else {
                downloadStatus = String(format: NSLocalizedString("model.status.download.failed", comment: "Model download failed"), nsError.localizedDescription)
                typelessError = .modelDownloadFailed(reason: nsError.localizedDescription)
            }

            NotificationCenter.default.post(name: .modelDownloadFinished, object: nil)
            NotificationCenter.default.post(name: .modelErrorOccurred, object: typelessError)

            return false
        }
    }

    // MARK: - WhisperKit Preloading

    func preloadWhisperKit() async {
        guard !isPreloading && whisperKit == nil else { return }

        isPreloading = true

        do {
            var config = WhisperKitConfig(model: currentModel)
            let loaded = try await WhisperKit(config)

            whisperKit = loaded
            isPreloading = false

            #if DEBUG
            print("✅ WhisperKit preloaded with model: \(currentModel)")
            #endif
        } catch {
            isPreloading = false
            #if DEBUG
            print("❌ WhisperKit preload failed: \(error)")
            #endif
        }
    }

    func getWhisperKit() -> WhisperKit? {
        return whisperKit
    }

    func resetWhisperKit() {
        whisperKit = nil
    }

    // MARK: - Private Helpers

    private func getModelPath(for model: String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return "\(documentsPath)/\(AppConstants.Storage.modelBasePath)/openai_whisper-\(model)"
    }
}

// Notification names are defined in MainView.swift