import Foundation
import AVFoundation
import Accelerate
import Combine
import WhisperKit

// MARK: - Audio Transcriber (Coordinator)

@MainActor
final class AudioTranscriber: ObservableObject {
    static let shared = AudioTranscriber()

    let recorder = AudioRecorder()
    let modelManager = ModelManager()
    let transcriptionService = TranscriptionService()
    let deviceManager = DeviceManager()
    let permissionManager = PermissionManager()

    // Live UI / shell state (menu, overlay, settings)
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var isModelReady = false
    @Published var bootStatus = "Starting…"
    @Published var volumeLevel: Double = 0.0
    @Published var audioDevices: [AudioDeviceModel] = []
    @Published var isQuickRecording = false
    /// Last user-facing error (menu tooltip / debug).
    @Published var lastErrorMessage: String?
    /// Shown in the dictate HUD as a failure (not a green "done" result).
    @Published var dictateFailure: String?

    private var quickRecordStartTime: Date?
    private var lastRecordingDuration: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    /// Bumps each stop so stale processAudio Tasks don't commit results.
    private var processGeneration = 0

    init() {
        setupBindings()
    }

    private func setupBindings() {
        recorder.$isRecording.assign(to: &$isRecording)
        recorder.$volumeLevel.assign(to: &$volumeLevel)

        modelManager.$isDownloading.assign(to: &$isDownloading)
        modelManager.$downloadProgress.assign(to: &$downloadProgress)
        modelManager.$isModelReady.assign(to: &$isModelReady)
        modelManager.$bootStatus.assign(to: &$bootStatus)

        transcriptionService.$isTranscribing.assign(to: &$isTranscribing)
        transcriptionService.$transcript.assign(to: &$transcript)

        deviceManager.$audioDevices.assign(to: &$audioDevices)
    }

    // MARK: - Errors

    func showError(_ error: TypelessError) {
        lastErrorMessage = error.errorDescription
        #if DEBUG
        print("❌ \(error.errorDescription ?? "error")")
        #endif
    }

    // MARK: - Model

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

    // MARK: - Recording

    @discardableResult
    func startRecordingAsync() async -> Bool {
        deviceManager.refreshDevices()

        let granted = await permissionManager.ensurePermission()
        guard granted else {
            showError(.microphonePermissionDenied)
            return false
        }

        do {
            try recorder.startRecording(deviceID: deviceManager.selectedDeviceID)
            return true
        } catch {
            showError(.audioEngineFailed(reason: error.localizedDescription))
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
            finishQuickSession()
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
                    failDictate(
                        NSLocalizedString("model.status.load.failed", comment: ""),
                        error: .modelLoadFailed(reason: "WhisperKit not initialized")
                    )
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
                        let payload = text
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            TextInserter.insert(payload)
                        }
                    }
                } else {
                    #if DEBUG
                    print("⚠️ Empty transcript for session")
                    #endif
                    // Don't put the error string into `transcript` — overlay would show a green check.
                    failDictate(
                        NSLocalizedString("error.transcription.emptyResult", comment: ""),
                        error: nil
                    )
                }

                if fromQuickRecord {
                    finishQuickSession()
                }
            } catch {
                #if DEBUG
                print("❌ processAudio: \(error)")
                #endif
                if generation == processGeneration {
                    let message = (error as? TypelessError)?.errorDescription
                        ?? error.localizedDescription
                    failDictate(message, error: error as? TypelessError
                        ?? .audioProcessingFailed(reason: error.localizedDescription))
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
                var scale = min(0.95 / peak, 40)
                vDSP_vsmul(channel, 1, &scale, channel, 1, vDSP_Length(frameCount))
            }
        }

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
        lastErrorMessage = nil
        dictateFailure = nil

        #if DEBUG
        print("🎤 beginQuickRecord ready=\(isModelReady) boot=\(bootStatus)")
        #endif

        if !isModelReady {
            Task { await modelManager.ensureWhisperKit() }
        }

        Task {
            let ok = await startRecordingAsync()
            if !ok {
                #if DEBUG
                print("🎤 beginQuickRecord failed to start capture")
                #endif
                // Clears isQuickRecording so MenuBarController can endSession.
                finishQuickSession()
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

        // Bluetooth often needs a short settle before first buffers.
        if bytes < 4096, isRecording {
            Task {
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

    private func failDictate(_ message: String, error: TypelessError?) {
        dictateFailure = message
        if let error {
            showError(error)
        } else {
            lastErrorMessage = message
        }
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

    func checkMicrophonePermission() {
        permissionManager.checkMicrophonePermission()
    }
}
