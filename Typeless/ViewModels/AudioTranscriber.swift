import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Audio Transcriber Delegate

protocol AudioTranscriberDelegate: AnyObject {
    func audioTranscriber(_ transcriber: AudioTranscriber, didEncounterError error: TypelessError)
    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateStatus status: String)
    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateProgress progress: Double)
}

// MARK: - Navigation

enum Navigation: Equatable {
    case main
    case settings
    case tutorial
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

    // MARK: - Delegates

    weak var delegate: AudioTranscriberDelegate?

    // MARK: - Published Properties

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

    // MARK: - Navigation State

    @Published var navigation: Navigation = .main

    // MARK: - Error State

    @Published var currentError: TypelessError?
    @Published var showErrorBanner = false
    private var isUserDismissed = false
    private var errorTimer: Timer?
    private var lastError: TypelessError?
    private var errorCount = 0

    // MARK: - Quick Record State

    @Published var isQuickRecording = false
    @Published var quickRecordCopied = false
    var quickRecordStartTime: Date?

    // MARK: - Private State

    private var selectedLanguage: String = "zh"
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

    // MARK: - Navigation Methods

    func navigate(to destination: Navigation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            navigation = destination
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            navigation = .main
        }
    }

    // MARK: - Error Handling

    func showError(_ error: TypelessError) {
        // Detect duplicate errors
        if lastError == error {
            errorCount += 1
            if errorCount >= 3 {
                print("⚠️ Repeated error: \(error.errorDescription ?? "Unknown")")
                return
            }
        } else {
            errorCount = 1
            lastError = error
        }

        currentError = error
        isUserDismissed = false

        withAnimation {
            showErrorBanner = true
        }

        // Clear previous timer
        errorTimer?.invalidate()

        // Set auto-dismiss duration based on error type
        let displayDuration: TimeInterval
        switch error.type {
        case .error: displayDuration = 5.0
        case .warning: displayDuration = 3.0
        case .info: displayDuration = 2.0
        }

        // Auto-dismiss for recoverable errors
        if error.isRecoverable {
            errorTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
                guard let self = self, !self.isUserDismissed else { return }
                withAnimation {
                    self.showErrorBanner = false
                }
            }
        }
    }

    func dismissError() {
        isUserDismissed = true
        errorTimer?.invalidate()
        errorTimer = nil
        withAnimation {
            showErrorBanner = false
        }
    }

    func cleanupErrorTimer() {
        errorTimer?.invalidate()
        errorTimer = nil
    }

    // MARK: - Quick Record

    func startQuickRecord() {
        isQuickRecording = true
        quickRecordStartTime = Date()
        quickRecordCopied = false
    }

    func stopQuickRecord() {
        isQuickRecording = false
        quickRecordStartTime = nil
    }

    func markQuickRecordCopied() {
        quickRecordCopied = true
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
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording_\(UUID().uuidString).wav")
            
            defer {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }

            do {
                let outputFormat = format ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                let audioFile = try AVAudioFile(forWriting: tempURL, settings: outputFormat.settings)
                
                // Convert Float32 data to AVAudioPCMBuffer and write
                let frameCount = data.count / MemoryLayout<Float>.size
                guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                    throw TypelessError.audioProcessingFailed(reason: "Failed to create PCM buffer")
                }
                buffer.frameLength = AVAudioFrameCount(frameCount)
                
                let floatData = data.withUnsafeBytes { $0.bindMemory(to: Float.self).baseAddress! }
                let channelData = buffer.floatChannelData![0]
                memcpy(channelData, floatData, data.count)
                
                try audioFile.write(from: buffer)

                guard let whisperKit = modelManager.getWhisperKit() else {
                    transcript = NSLocalizedString("model.status.load.failed", comment: "Model failed to load")
                    return
                }

                await transcriptionService.transcribe(audioFilePath: tempURL.path, using: whisperKit)
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
    }
    
    func reset() {
        navigation = .main
        cleanupErrorTimer()
        currentError = nil
        showErrorBanner = false
        isQuickRecording = false
        quickRecordStartTime = nil
        quickRecordCopied = false
    }
}