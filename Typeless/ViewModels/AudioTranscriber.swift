import Foundation
import AVFoundation
import Accelerate
import Combine
import SwiftUI
import AppKit
import WhisperKit

// MARK: - Navigation

enum Navigation: Equatable {
    case main
    case settings
    case tutorial
}

// MARK: - Audio Transcriber (Coordinator)

@MainActor
final class AudioTranscriber: ObservableObject {
    static let shared = AudioTranscriber()

    let recorder = AudioRecorder()
    let modelManager = ModelManager()
    let transcriptionService = TranscriptionService()
    let deviceManager = DeviceManager()
    let permissionManager = PermissionManager()

    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    @Published var hasValidTranscript = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = NSLocalizedString("model.status.preparing", comment: "Preparing to download model")
    @Published var isModelReady = false
    @Published var bootStatus = "Starting…"
    @Published var volumeLevel: Double = 0.0
    @Published var recordingTime: TimeInterval = 0.0
    @Published var audioDevices: [AudioDeviceModel] = []
    @Published var selectedDeviceIndex = 0
    @Published var hasMicrophonePermission = false
    @Published var isCheckingPermission = true

    @Published var navigation: Navigation = .main
    @Published var currentError: TypelessError?
    @Published var showErrorBanner = false
    @Published var isQuickRecording = false

    private var isUserDismissed = false
    private var errorTimer: Timer?
    private var lastError: TypelessError?
    private var errorCount = 0
    private var quickRecordStartTime: Date?
    private var lastRecordingDuration: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    /// Bumps each stop so stale processAudio Tasks don't commit results.
    private var processGeneration = 0

    init() {
        setupBindings()
        setupErrorObservers()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    private func setupBindings() {
        recorder.$isRecording.assign(to: &$isRecording)
        recorder.$volumeLevel.assign(to: &$volumeLevel)
        recorder.$recordingTime.assign(to: &$recordingTime)

        modelManager.$isDownloading.assign(to: &$isDownloading)
        modelManager.$downloadProgress.assign(to: &$downloadProgress)
        modelManager.$downloadStatus.assign(to: &$downloadStatus)
        modelManager.$isModelReady.assign(to: &$isModelReady)
        modelManager.$bootStatus.assign(to: &$bootStatus)

        transcriptionService.$isTranscribing.assign(to: &$isTranscribing)
        transcriptionService.$transcript.assign(to: &$transcript)
        transcriptionService.$hasValidTranscript.assign(to: &$hasValidTranscript)

        deviceManager.$audioDevices.assign(to: &$audioDevices)
        deviceManager.$selectedDeviceIndex.assign(to: &$selectedDeviceIndex)

        permissionManager.$hasMicrophonePermission.assign(to: &$hasMicrophonePermission)
        permissionManager.$isCheckingPermission.assign(to: &$isCheckingPermission)
    }

    private func setupErrorObservers() {
        NotificationCenter.default.publisher(for: .modelErrorOccurred)
            .compactMap { $0.object as? TypelessError }
            .sink { [weak self] error in self?.showError(error) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .transcriptionError)
            .compactMap { $0.object as? TypelessError }
            .sink { [weak self] error in self?.showError(error) }
            .store(in: &cancellables)
    }

    // MARK: - Navigation

    func navigate(to destination: Navigation) {
        if destination == .settings {
            AppWindows.openSettings()
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            navigation = destination
        }
    }

    // MARK: - Errors

    func showError(_ error: TypelessError) {
        if lastError == error {
            errorCount += 1
            if errorCount >= 3 { return }
        } else {
            errorCount = 1
            lastError = error
        }
        currentError = error
        isUserDismissed = false
        withAnimation { showErrorBanner = true }
        errorTimer?.invalidate()
        let duration: TimeInterval
        switch error.type {
        case .error: duration = 5.0
        case .warning: duration = 3.0
        case .info: duration = 2.0
        }
        if error.isRecoverable {
            errorTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                guard let self, !self.isUserDismissed else { return }
                withAnimation { self.showErrorBanner = false }
            }
        }
    }

    func dismissError() {
        isUserDismissed = true
        errorTimer?.invalidate()
        errorTimer = nil
        withAnimation { showErrorBanner = false }
    }

    func cleanupErrorTimer() {
        errorTimer?.invalidate()
        errorTimer = nil
    }

    // MARK: - Model

    var isModelDownloaded: Bool { modelManager.isModelDownloaded }

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

    /// Launch path: download if needed + load into memory.
    func prepareModelAtLaunch() async {
        await modelManager.prepareModelAtLaunch()
    }

    func forceRetryDownload() {
        Task {
            _ = await checkAndDownloadModelIfNeeded()
            if isModelDownloaded {
                await preloadWhisperKit()
            }
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    func startRecording() {
        Task { await startRecordingAsync() }
    }

    @discardableResult
    func startRecordingAsync() async -> Bool {
        deviceManager.refreshDevices()

        let granted = await permissionManager.ensurePermission()
        guard granted else {
            showError(.microphonePermissionDenied)
            return false
        }

        // Don't hard-fail on empty list — capture session can still use default mic.
        do {
            try recorder.startRecording(deviceID: deviceManager.selectedDeviceID)
            return true
        } catch {
            showError(.audioEngineFailed(reason: error.localizedDescription))
            #if DEBUG
            print("❌ startRecording: \(error)")
            #endif
            return false
        }
    }

    func stopRecording() {
        lastRecordingDuration = max(recorder.recordingTime, 0)
        let (data, format) = recorder.stopRecording()

        // ~0.15s mono float @ 16–48 kHz
        let minBytes = 2 * 1024
        guard data.count >= minBytes else {
            #if DEBUG
            print("❌ Empty/short capture: \(data.count) bytes")
            #endif
            if isQuickRecording {
                finishQuickSession()
            } else {
                transcript = NSLocalizedString("error.transcription.emptyResult", comment: "")
            }
            return
        }
        processGeneration += 1
        let generation = processGeneration
        processAudio(data: data, format: format, generation: generation, fromQuickRecord: isQuickRecording)
    }

    // MARK: - Process + transcribe

    private func processAudio(data: Data, format: AVAudioFormat?, generation: Int, fromQuickRecord: Bool) {
        Task {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("recording_\(UUID().uuidString).wav")

            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            do {
                try Self.writeWAV(data: data, format: format, to: tempURL)

                guard generation == processGeneration else {
                    #if DEBUG
                    print("⏭ Stale processAudio ignored (gen \(generation)/\(processGeneration))")
                    #endif
                    return
                }

                guard let whisperKit = await modelManager.ensureWhisperKit() else {
                    transcript = NSLocalizedString("model.status.load.failed", comment: "")
                    if fromQuickRecord { finishQuickSession() }
                    return
                }

                let text = await transcriptionService.transcribe(
                    audioFilePath: tempURL.path,
                    using: whisperKit
                )

                guard generation == processGeneration else { return }

                if !text.isEmpty {
                    HistoryStore.shared.add(
                        duration: lastRecordingDuration,
                        transcript: text,
                        language: transcriptionServiceLanguage(),
                        model: modelManager.modelName
                    )
                    if fromQuickRecord {
                        // Let modifier keys from the hold-shortcut fully release,
                        // then insert into the still-focused field.
                        let payload = text
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            TextInserter.insert(payload)
                        }
                    }
                } else {
                    #if DEBUG
                    print("⚠️ Empty transcript for session")
                    #endif
                }

                if fromQuickRecord {
                    finishQuickSession()
                }
            } catch {
                #if DEBUG
                print("❌ processAudio: \(error)")
                #endif
                if generation == processGeneration {
                    showError(.audioProcessingFailed(reason: error.localizedDescription))
                    if fromQuickRecord { finishQuickSession() }
                }
            }
        }
    }

    /// Resample to 16 kHz mono, peak-normalize, write WAV (Whisper native rate).
    private static func writeWAV(data: Data, format: AVAudioFormat?, to url: URL) throws {
        let sourceRate = format?.sampleRate ?? 48000
        let frameCount = data.count / MemoryLayout<Float>.size
        guard frameCount > 0 else {
            throw TypelessError.audioProcessingFailed(reason: "No frames")
        }

        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceRate,
            channels: 1,
            interleaved: false
        ) else {
            throw TypelessError.audioProcessingFailed(reason: "Bad source format")
        }

        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw TypelessError.audioProcessingFailed(reason: "Source buffer alloc failed")
        }
        sourceBuffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { raw in
            guard let src = raw.bindMemory(to: Float.self).baseAddress,
                  let dst = sourceBuffer.floatChannelData?[0]
            else { return }
            memcpy(dst, src, data.count)
        }

        // Peak normalize. Reject near-silence (Bluetooth converter failures look like "data" but peak≈0).
        if let channel = sourceBuffer.floatChannelData?[0] {
            var peak: Float = 0
            vDSP_maxmgv(channel, 1, &peak, vDSP_Length(frameCount))
            #if DEBUG
            print("🔊 PCM peak=\(String(format: "%.5f", peak)) frames=\(frameCount) rate=\(sourceRate)")
            #endif
            if peak < 0.0008 {
                throw TypelessError.audioProcessingFailed(
                    reason: "Microphone signal too weak (silence). Try Built-in Mic, or re-select AirPods in Settings → Dictation."
                )
            }
            if peak < 0.95 {
                var scale = min(0.95 / peak, 40) // cap boost
                vDSP_vsmul(channel, 1, &scale, channel, 1, vDSP_Length(frameCount))
            }
        }

        // Resample to Whisper's 16 kHz.
        let targetRate: Double = 16_000
        let processed: AVAudioPCMBuffer
        if abs(sourceRate - targetRate) < 1 {
            processed = sourceBuffer
        } else if let resampled = AudioProcessor.resampleAudio(
            fromBuffer: sourceBuffer,
            toSampleRate: targetRate,
            channelCount: 1
        ) {
            processed = resampled
        } else {
            // Fallback: write original rate; WhisperKit will resample on load.
            processed = sourceBuffer
        }

        let audioFile = try AVAudioFile(forWriting: url, settings: processed.format.settings)
        try audioFile.write(from: processed)

        #if DEBUG
        print("💾 WAV \(processed.frameLength) frames @ \(processed.format.sampleRate) Hz (from \(sourceRate))")
        #endif
    }

    // MARK: - Quick record (dictate)

    func beginQuickRecord() {
        if isTranscribing {
            processGeneration += 1
            transcriptionService.cancel()
        }
        if isRecording {
            _ = recorder.stopRecording()
        }

        isQuickRecording = true
        quickRecordStartTime = Date()
        hasValidTranscript = false

        #if DEBUG
        print("🎤 beginQuickRecord ready=\(isModelReady) boot=\(bootStatus)")
        #endif

        if !isModelReady {
            Task { await modelManager.ensureWhisperKit() }
        }

        // Always go through async path (permission + capture session).
        Task {
            let ok = await startRecordingAsync()
            if !ok {
                #if DEBUG
                print("🎤 beginQuickRecord failed to start capture")
                #endif
                // Allow a moment for session to come up; don't clear flag immediately.
            }
        }
    }

    func endQuickRecord() {
        guard isQuickRecording else { return }

        let start = quickRecordStartTime ?? Date()
        let duration = Date().timeIntervalSince(start)
        let bytes = recorder.capturedByteCount

        #if DEBUG
        print("🎤 endQuickRecord t=\(String(format: "%.2f", duration))s recording=\(isRecording) bytes=\(bytes)")
        #endif

        // Bluetooth (AirPods) often needs ~0.4–0.6s before first buffers arrive.
        // If user released early and we have no audio yet, wait briefly for data.
        if bytes < 4096, isRecording {
            Task {
                // Poll up to ~0.5s for first audio
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    if recorder.capturedByteCount >= 4096 { break }
                    if !isRecording && !isQuickRecording { return }
                }
                await MainActor.run {
                    guard self.isQuickRecording else { return }
                    self.finishEndQuickRecord()
                }
            }
            return
        }

        finishEndQuickRecord()
    }

    private func finishEndQuickRecord() {
        guard isQuickRecording else { return }
        let bytes = recorder.capturedByteCount
        let duration = quickRecordStartTime.map { Date().timeIntervalSince($0) } ?? 0

        if duration < 0.4 && bytes < 2048 {
            if isRecording { _ = recorder.stopRecording() }
            finishQuickSession()
            return
        }

        if isRecording || bytes > 0 {
            stopRecording()
        } else {
            finishQuickSession()
        }
    }

    private func finishQuickSession() {
        isQuickRecording = false
        quickRecordStartTime = nil
    }

    // MARK: - Language / device / permission

    func setLanguage(_ language: String) {
        transcriptionService.setLanguage(language)
    }

    private func transcriptionServiceLanguage() -> String {
        UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "zh"
    }

    func setSelectedDevice(index: Int) {
        deviceManager.setSelectedDevice(index: index)
    }

    func getAvailableAudioDevices() {
        deviceManager.refreshDevices()
    }

    func hasAvailableAudioInputDevices() -> Bool {
        deviceManager.hasAvailableDevices
    }

    func checkMicrophonePermission() {
        permissionManager.checkMicrophonePermission()
    }

    func requestMicrophonePermission() {
        permissionManager.requestMicrophonePermission()
    }

    func copyTranscriptToClipboard() {
        guard hasValidTranscript, !transcript.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
    }

    func cleanup() {
        processGeneration += 1
        transcriptionService.cancel()
        _ = recorder.stopRecording()
        finishQuickSession()
    }
}
