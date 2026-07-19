import Foundation
import AVFoundation
import Combine

// MARK: - Audio Recorder

@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var volumeLevel: Double = 0.0
    @Published var recordingTime: TimeInterval = 0.0

    private var audioEngine: AVAudioEngine?
    private var audioFormat: AVAudioFormat?
    private var audioData = Data()
    private var audioDataSizeWarning = false
    private var recordingTimer: Timer?
    private let dataLock = NSLock()

    // MARK: - Public Methods

    var recordedData: Data {
        dataLock.lock()
        defer { dataLock.unlock() }
        return audioData
    }

    var format: AVAudioFormat? { audioFormat }

    func startRecording() throws {
        guard !isRecording else { return }

        // Reset data
        dataLock.lock()
        audioData = Data()
        audioDataSizeWarning = false
        dataLock.unlock()
        recordingTime = 0.0

        // Setup audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let bus: AVAudioNodeBus = 0
        let inputFormat = inputNode.outputFormat(forBus: bus)
        audioFormat = inputFormat

        #if DEBUG
        print("Audio format: \(inputFormat)")
        print("Sample rate: \(inputFormat.sampleRate)")
        print("Channels: \(inputFormat.channelCount)")
        #endif

        // Install tap to capture audio
        inputNode.installTap(onBus: bus, bufferSize: AppConstants.Audio.bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            let volume = self.calculateVolume(from: buffer)

            Task { @MainActor in
                self.volumeLevel = volume
            }

            if let bufferData = self.audioBufferToData(buffer, channelCount: channelCount, frameLength: frameLength) {
                self.dataLock.lock()
                let maxBytes = AppConstants.Audio.maxRecordingDataSize
                if self.audioData.count + bufferData.count <= maxBytes {
                    self.audioData.append(bufferData)
                } else if !self.audioDataSizeWarning {
                    self.audioDataSizeWarning = true
                    #if DEBUG
                    print("⚠️ Audio data buffer approaching limit (\(maxBytes / 1024 / 1024)MB)")
                    #endif
                }
                self.dataLock.unlock()
            }
        }

        // Disconnect main mixer to avoid feedback
        engine.disconnectNodeInput(engine.mainMixerNode)

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        isRecording = true

        // Start recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.Recording.timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += AppConstants.Recording.timerInterval
            }
        }

        #if DEBUG
        print("🎙️ Recording started")
        #endif
    }

    func stopRecording() -> (data: Data, format: AVAudioFormat?) {
        guard isRecording else { return (Data(), nil) }

        isRecording = false
        recordingTime = 0.0

        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop engine first, then capture final data under lock
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        // Capture data synchronously after engine is stopped
        dataLock.lock()
        let capturedData = audioData
        let capturedFormat = audioFormat
        audioData = Data()
        dataLock.unlock()

        #if DEBUG
        print("⏹️ Recording stopped, data size: \(capturedData.count) bytes")
        #endif

        return (capturedData, capturedFormat)
    }

    // MARK: - Volume Calculation

    private func calculateVolume(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.0 }

        let data = channelData[0]
        var sum: Double = 0.0

        for i in 0..<frameLength {
            let sample = data[i]
            sum += Double(sample * sample)
        }

        let mean = sum / Double(frameLength)
        let rms = sqrt(mean)
        let db = 20 * log10(rms)

        let minDB = AppConstants.Audio.minDB
        let maxDB = AppConstants.Audio.maxDB
        var level = (db - minDB) / (maxDB - minDB)
        level = max(0.0, min(1.0, level))

        // Enhance sensitivity
        level = level * level * 2.0
        level = min(1.0, level)

        return level
    }

    // MARK: - Buffer Conversion

    private func audioBufferToData(_ buffer: AVAudioPCMBuffer, channelCount: Int, frameLength: Int) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }
        guard frameLength > 0 else { return nil }

        let byteSize = frameLength * MemoryLayout<Float>.size
        return Data(bytes: channelData[0], count: byteSize)
    }
}