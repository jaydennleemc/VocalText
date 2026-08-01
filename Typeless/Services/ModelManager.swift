import Foundation
import AppKit
import WhisperKit

// MARK: - Model Manager

@MainActor
final class ModelManager: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var isModelReady = false
    @Published var bootStatus = "Starting…"
    @Published var lastLoadError: String?

    private var currentModel = "medium"
    private var whisperKit: WhisperKit?
    private var isPreloading = false
    private let modelBasePath = "huggingface/models/argmaxinc/whisperkit-coreml"
    private let allowedModels: Set<String> = ["small", "medium", "large-v3"]

    func setModel(_ model: String) {
        var name = model.lowercased()
        if !allowedModels.contains(name) { name = "medium" }
        if name != currentModel {
            whisperKit = nil
            isModelReady = false
        }
        currentModel = name
    }

    var modelName: String { currentModel }

    func isModelAlreadyDownloaded(model: String? = nil) -> Bool {
        let modelName = (model ?? currentModel).lowercased()
        let modelPath = getModelPath(for: modelName)
        let fm = FileManager.default
        guard fm.fileExists(atPath: modelPath) else { return false }

        for dir in ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"] {
            var isDir: ObjCBool = false
            let p = (modelPath as NSString).appendingPathComponent(dir)
            guard fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue else { return false }
        }
        let config = (modelPath as NSString).appendingPathComponent("config.json")
        let configAlt = (modelPath as NSString).appendingPathComponent("Config.json")
        return fm.fileExists(atPath: config) || fm.fileExists(atPath: configAlt)
    }

    func checkAndDownloadModelIfNeeded() async -> Bool {
        if isModelAlreadyDownloaded() { return true }

        do {
            isDownloading = true
            isModelReady = false
            lastLoadError = nil
            bootStatus = "Downloading \(currentModel)…"
            downloadProgress = 0

            let progressHandler: (Progress) -> Void = { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress.fractionCompleted
                    let pct = Int(progress.fractionCompleted * 100)
                    self?.bootStatus = "Downloading \(self?.currentModel ?? "")… \(pct)%"
                }
            }

            _ = try await WhisperKit.download(
                variant: currentModel,
                progressCallback: progressHandler
            )

            isDownloading = false
            bootStatus = "Download complete"
            return true
        } catch {
            isDownloading = false
            isModelReady = false
            bootStatus = "Download failed"
            lastLoadError = error.localizedDescription
            return false
        }
    }

    func prepareModelAtLaunch() async {
        bootStatus = "Checking model…"
        lastLoadError = nil
        if !isModelAlreadyDownloaded() {
            guard await checkAndDownloadModelIfNeeded() else { return }
        }
        bootStatus = "Loading \(currentModel)…"
        await preloadWhisperKit()
    }

    func preloadWhisperKit() async {
        if whisperKit != nil {
            isModelReady = true
            bootStatus = "Ready"
            return
        }
        guard !isPreloading else { return }
        isPreloading = true
        isModelReady = false
        bootStatus = "Loading \(currentModel)…"
        lastLoadError = nil

        let folder = localModelFolderIfPresent()

        let attempts: [WhisperKitConfig] = [
            WhisperKitConfig(
                model: currentModel,
                modelFolder: folder,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: true,
                download: folder == nil
            ),
            WhisperKitConfig(
                model: currentModel,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: true,
                download: true
            ),
        ]

        var lastError: Error?
        for (i, config) in attempts.enumerated() {
            do {
                #if DEBUG
                print("⏳ Load #\(i) model=\(currentModel) folder=\(folder ?? "nil")")
                #endif
                whisperKit = try await WhisperKit(config)
                isPreloading = false
                isModelReady = true
                bootStatus = "Ready"
                lastLoadError = nil
                #if DEBUG
                print("✅ Ready: \(currentModel)")
                #endif
                return
            } catch {
                lastError = error
                #if DEBUG
                print("❌ Load #\(i): \(error)")
                #endif
            }
        }

        isPreloading = false
        isModelReady = false
        bootStatus = "Load failed"
        lastLoadError = lastError?.localizedDescription ?? "Unknown"
    }

    func ensureWhisperKit() async -> WhisperKit? {
        if let whisperKit {
            isModelReady = true
            return whisperKit
        }
        await preloadWhisperKit()
        return whisperKit
    }

    private func localModelFolderIfPresent() -> String? {
        let path = getModelPath(for: currentModel)
        return isModelAlreadyDownloaded() ? path : nil
    }

    private func getModelPath(for model: String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return "\(documentsPath)/\(modelBasePath)/openai_whisper-\(model)"
    }
}
