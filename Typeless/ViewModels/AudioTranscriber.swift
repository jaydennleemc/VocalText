import Foundation
import AVFoundation
import Combine

// MARK: - Audio Transcriber Delegate

protocol AudioTranscriberDelegate: AnyObject {
    func audioTranscriber(_ transcriber: AudioTranscriber, didEncounterError error: TypelessError)
    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateStatus status: String)
    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateProgress progress: Double)
}

// MARK: - Audio Transcriber (Coordinator)

@MainActor
final class AudioTranscriber: ObservableObject {
    /// Shared singleton for cross-component access (e.g., overlay window)
    static let shared = AudioTranscriber()

    // MARK: - Services

    let recorder = AudioRecorder()
    let modelManager = ModelManager()
    let transcriptionService = TranscriptionService()
    let deviceManager = DeviceManager()
    let permissionManager = PermissionManager()
    let fileWriter = AudioFileWriter()

    // MARK: - Delegates

    weak var delegate: AudioTranscriberDelegate?

    // MARK: - Published Properties (Forwarded)

    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var transcript: String = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    @Published var hasValidTranscript = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = NSLocalizedString("model.status.preparing", comment: "Preparing to download model")
    @Published var volumeLevel: Double = 0.0
    @Published var recordingTime: TimeInterval = 0.0
    @Published var audioDevices: [AudioDeviceModel] = []
    @Published var selectedDeviceIndex = 0
    @Published var hasMicrophonePermission = false
    @Published var isCheckingPermission = true

    // MARK: - Private State

    private var selectedLanguage: String = AppConstants.Defaults.language
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
        setupNotificationObservers()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Forward recorder state
        recorder.$isRecording
            .assign(to: &$isRecording)
        recorder.$volumeLevel
            .assign(to: &$volumeLevel)
        recorder.$recordingTime
            .assign(to: &$recordingTime)

        // Forward model manager state
        modelManager.$isDownloading
            .assign(to: &$isDownloading)
        modelManager.$downloadProgress
            .assign(to: &$downloadProgress)
        modelManager.$downloadStatus
            .assign(to: &$downloadStatus)

        // Forward transcription state
        transcriptionService.$isTranscribing
            .assign(to: &$isTranscribing)
        transcriptionService.$transcript
            .assign(to: &$transcript)
        transcriptionService.$hasValidTranscript
            .assign(to: &$hasValidTranscript)

        // Forward device state
        deviceManager.$audioDevices
            .assign(to: &$audioDevices)
        deviceManager.$selectedDeviceIndex
            .assign(to: &$selectedDeviceIndex)

        // Forward permission state
        permissionManager.$hasMicrophonePermission
            .assign(to: &$hasMicrophonePermission)
        permissionManager.$isCheckingPermission
            .assign(to: &$isCheckingPermission)
    }

    private func setupNotificationObservers() {
        // Model errors
        NotificationCenter.default.publisher(for: .modelErrorOccurred)
            .compactMap { $0.object as? TypelessError }
            .sink { [weak self] error in
                guard let self else { return }
                self.delegate?.audioTranscriber(self, didEncounterError: error)
            }
            .store(in: &cancellables)

        // Transcription errors
        NotificationCenter.default.publisher(for: .transcriptionError)
            .compactMap { $0.object as? TypelessError }
            .sink { [weak self] error in
                guard let self else { return }
                self.delegate?.audioTranscriber(self, didEncounterError: error)
            }
            .store(in: &cancellables)
    }

    // MARK: - Model Management

    var isModelDownloaded: Bool {
        modelManager.isModelDownloaded
    }

    func isModelAlreadyDownloaded(model: String) -> Bool {
        modelManager.isModelAlreadyDownloaded(model: model)
    }

    func setModel(_ model: String) {
        modelManager.setModel(model)
    }

    func checkAndDownloadModelIfNeeded() async -> Bool {
        await modelManager.checkAndDownloadModelIfNeeded()
    }

    func preloadWhisperKit() async {
        await modelManager.preloadWhisperKit()
    }

    // MARK: - Recording

    func startRecording() {
        guard permissionManager.hasMicrophonePermission else {
            delegate?.audioTranscriber(self, didEncounterError: .microphonePermissionDenied)
            return
        }

        guard deviceManager.hasAvailableDevices else {
            delegate?.audioTranscriber(self, didEncounterError: .audioDeviceUnavailable)
            return
        }

        guard modelManager.isModelAlreadyDownloaded() else {
            transcript = NSLocalizedString("model.status.download.required", comment: "Model not downloaded")
            return
        }

        do {
            try recorder.startRecording()
            NotificationCenter.default.post(name: .recordingStarted, object: nil)
        } catch {
            delegate?.audioTranscriber(self, didEncounterError: .audioEngineFailed(reason: error.localizedDescription))
        }
    }

    func stopRecording() {
        let (data, format) = recorder.stopRecording()
        NotificationCenter.default.post(name: .recordingStopped, object: nil)

        guard !data.isEmpty else {
            transcript = NSLocalizedString("error.transcription.emptyResult", comment: "No audio data recorded")
            delegate?.audioTranscriber(self, didEncounterError: .transcriptionEmptyResult)
            return
        }

        processAudio(data: data, format: format)
    }

    // MARK: - Audio Processing

    private func processAudio(data: Data, format: AVAudioFormat?) {
        Task {
            var tempURL: URL?

            defer {
                if let url = tempURL, FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
            }

            do {
                tempURL = try fileWriter.createSecureTempFile()
                guard let fileURL = tempURL else { return }

                try fileWriter.saveAudioDataToWAV(data, format: format, url: fileURL)

                guard let whisperKit = modelManager.getWhisperKit() else {
                    transcript = NSLocalizedString("model.status.load.failed", comment: "Model failed to load")
                    return
                }

                await transcriptionService.transcribe(audioFilePath: fileURL.path, using: whisperKit)
            } catch {
                transcript = String(format: NSLocalizedString("error.audio.processingFailed", comment: "Audio processing failed"), error.localizedDescription)
                delegate?.audioTranscriber(self, didEncounterError: .audioProcessingFailed(reason: error.localizedDescription))
            }
        }
    }

    // MARK: - Language

    func setLanguage(_ language: String) {
        selectedLanguage = language
        transcriptionService.setLanguage(language)
    }

    // MARK: - Device

    func setSelectedDevice(index: Int) {
        deviceManager.setSelectedDevice(index: index)
    }

    func getAvailableAudioDevices() {
        deviceManager.refreshDevices()
    }

    func hasAvailableAudioInputDevices() -> Bool {
        deviceManager.hasAvailableDevices
    }

    // MARK: - Permission

    func checkMicrophonePermission() {
        permissionManager.checkMicrophonePermission()
    }

    func requestMicrophonePermission() {
        permissionManager.requestMicrophonePermission()
    }

    // MARK: - Cleanup

    func cleanup() {
        recorder.stopRecording()
        fileWriter.cleanupTempFiles()
    }
}