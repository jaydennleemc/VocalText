import Foundation
import AVFoundation
import Accelerate
import CoreMedia
import AudioToolbox

// MARK: - Thread-safe store

private final class PCMBufferStore: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let maxBytes = 100 * 1024 * 1024
    private(set) var sampleRate: Double = 48_000
    private(set) var peak: Float = 0

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return data.count
    }

    func reset(sampleRate: Double = 48_000) {
        lock.lock()
        data = Data()
        self.sampleRate = sampleRate
        peak = 0
        lock.unlock()
    }

    func append(_ chunk: Data, sampleRate: Double, framePeak: Float) {
        lock.lock()
        if sampleRate > 1000 { self.sampleRate = sampleRate }
        peak = max(peak, framePeak)
        if data.count + chunk.count <= maxBytes {
            data.append(chunk)
        }
        lock.unlock()
    }

    func takeAll() -> (data: Data, sampleRate: Double, peak: Float) {
        lock.lock()
        let out = data
        let rate = sampleRate
        let p = peak
        data = Data()
        peak = 0
        lock.unlock()
        return (out, rate, p)
    }
}

// MARK: - Audio Recorder

/// Microphone capture via AVCaptureSession (native device format — no forced converter).
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var volumeLevel: Double = 0.0
    @Published var recordingTime: TimeInterval = 0.0

    private let session = AVCaptureSession()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.typeless.audio.capture", qos: .userInitiated)
    private let store = PCMBufferStore()

    private var recordingTimer: Timer?
    private var startedAt: Date?

    var format: AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: store.sampleRate,
            channels: 1,
            interleaved: false
        )
    }

    var capturedByteCount: Int { store.count }

    // MARK: - Start / Stop

    func startRecording(deviceID: String? = nil) throws {
        _ = stopInternal(clearData: true, silent: true)

        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            throw TypelessError.microphonePermissionDenied
        }

        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        guard let device = Self.resolveDevice(preferredID: deviceID) else {
            session.commitConfiguration()
            throw TypelessError.audioDeviceUnavailable
        }

        #if DEBUG
        print("🎙️ Using mic: \(device.localizedName)")
        #endif

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw TypelessError.audioEngineFailed(reason: "Cannot add mic input")
        }
        session.addInput(input)

        // IMPORTANT: do NOT force audioSettings — Bluetooth (AirPods) converters often fail
        // and produce silence / empty frames. Accept native format and convert ourselves.
        audioOutput.audioSettings = nil
        audioOutput.setSampleBufferDelegate(self, queue: sampleQueue)

        guard session.canAddOutput(audioOutput) else {
            session.commitConfiguration()
            throw TypelessError.audioEngineFailed(reason: "Cannot add audio output")
        }
        session.addOutput(audioOutput)
        session.commitConfiguration()

        var rate = 48_000.0
        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(
            device.activeFormat.formatDescription
        )?.pointee, asbd.mSampleRate > 1000 {
            rate = asbd.mSampleRate
        }
        store.reset(sampleRate: rate)
        recordingTime = 0
        volumeLevel = 0
        startedAt = Date()

        let session = self.session
        sampleQueue.async {
            if !session.isRunning {
                session.startRunning()
            }
        }

        isRecording = true
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording, let started = self.startedAt else { return }
                self.recordingTime = Date().timeIntervalSince(started)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        recordingTimer = timer

        #if DEBUG
        print("🎙️ Capture started (native format) @~\(rate) Hz")
        #endif
    }

    func stopRecording() -> (data: Data, format: AVAudioFormat?) {
        guard isRecording else { return (Data(), nil) }
        return stopInternal(clearData: false, silent: false)
    }

    @discardableResult
    private func stopInternal(clearData: Bool, silent: Bool) -> (data: Data, format: AVAudioFormat?) {
        let wasRecording = isRecording
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        startedAt = nil

        if session.isRunning {
            let session = self.session
            sampleQueue.sync { session.stopRunning() }
        }
        audioOutput.setSampleBufferDelegate(nil, queue: nil)

        let taken = store.takeAll()
        volumeLevel = 0
        recordingTime = 0

        if clearData {
            store.reset()
        }

        let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: taken.sampleRate > 1000 ? taken.sampleRate : 48_000,
            channels: 1,
            interleaved: false
        )

        #if DEBUG
        if !silent || wasRecording {
            print("⏹️ Stop: \(taken.data.count) bytes, peak=\(String(format: "%.4f", taken.peak)), t=\(String(format: "%.2f", duration))s, rate=\(taken.sampleRate)")
        }
        #endif

        return (taken.data, fmt)
    }

    private static func resolveDevice(preferredID: String?) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let devices = discovery.devices
        if let preferredID, let match = devices.first(where: { $0.uniqueID == preferredID }) {
            return match
        }
        // Prefer built-in over Bluetooth when no preference (more reliable for speech).
        if let builtIn = devices.first(where: {
            $0.localizedName.localizedCaseInsensitiveContains("built-in")
                || $0.localizedName.localizedCaseInsensitiveContains("内建")
                || $0.localizedName.localizedCaseInsensitiveContains("MacBook")
        }) {
            return builtIn
        }
        return devices.first ?? AVCaptureDevice.default(for: .audio)
    }
}

// MARK: - Sample buffers

extension AudioRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return
        }
        let asbd = asbdPtr.pointee
        let channels = max(1, Int(asbd.mChannelsPerFrame))
        let rate = asbd.mSampleRate > 1000 ? asbd.mSampleRate : 48_000

        // Preferred: AudioBufferList (handles non-interleaved correctly).
        var mono: [Float] = []
        if let floats = Self.floatsFromSampleBuffer(sampleBuffer, asbd: asbd, channels: channels) {
            mono = floats
        } else {
            return
        }
        guard !mono.isEmpty else { return }

        var peak: Float = 0
        vDSP_maxmgv(mono, 1, &peak, vDSP_Length(mono.count))
        var rms: Float = 0
        vDSP_rmsqv(mono, 1, &rms, vDSP_Length(mono.count))
        // Linear-ish meter: quieter speech still moves the HUD bars.
        let rmsNorm = min(1.0, Double(rms) * 8.0)
        let peakNorm = min(1.0, Double(peak) * 2.2)
        let display = min(1.0, max(rmsNorm, peakNorm * 0.85))

        let chunk = mono.withUnsafeBufferPointer { Data(buffer: $0) }
        store.append(chunk, sampleRate: rate, framePeak: peak)

        Task { @MainActor in
            // Attack fast, release medium — avoids a sluggish waveform.
            let previous = self.volumeLevel
            if display >= previous {
                self.volumeLevel = previous * 0.25 + display * 0.75
            } else {
                self.volumeLevel = previous * 0.55 + display * 0.45
            }
        }
    }

    /// Convert CMSampleBuffer → mono Float32 using AudioBufferList.
    nonisolated private static func floatsFromSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        asbd: AudioStreamBasicDescription,
        channels: Int
    ) -> [Float]? {
        var bufferListSizeNeeded = 0
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: nil
        )
        // First call may return err when size needed — that's OK.
        guard bufferListSizeNeeded > 0 || status == noErr else {
            // Fallback: raw block buffer
            return floatsFromBlockBuffer(sampleBuffer, asbd: asbd, channels: channels)
        }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: max(bufferListSizeNeeded, MemoryLayout<AudioBufferList>.size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        let audioBufferList = raw.bindMemory(to: AudioBufferList.self, capacity: 1)

        var blockBuffer: CMBlockBuffer?
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: bufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else {
            return floatsFromBlockBuffer(sampleBuffer, asbd: asbd, channels: channels)
        }
        defer { blockBuffer = nil }

        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let bits = Int(asbd.mBitsPerChannel)
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        // Determine frame count from first buffer
        guard let first = abl.first, let mData = first.mData else { return nil }
        let bytesPerFrame = max(1, Int(asbd.mBytesPerFrame))
        let frames: Int
        if isNonInterleaved {
            frames = Int(first.mDataByteSize) / max(1, bits / 8)
        } else {
            frames = Int(first.mDataByteSize) / bytesPerFrame
        }
        guard frames > 0 else { return nil }

        var mono = [Float](repeating: 0, count: frames)

        if isFloat && bits == 32 {
            if isNonInterleaved {
                // Average planes
                let planeCount = abl.count
                for p in 0..<planeCount {
                    guard let ptr = abl[p].mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for i in 0..<frames {
                        mono[i] += ptr[i]
                    }
                }
                if planeCount > 1 {
                    var scale = 1.0 / Float(planeCount)
                    vDSP_vsmul(mono, 1, &scale, &mono, 1, vDSP_Length(frames))
                }
            } else {
                let ptr = mData.assumingMemoryBound(to: Float.self)
                if channels == 1 {
                    for i in 0..<frames { mono[i] = ptr[i] }
                } else {
                    for i in 0..<frames {
                        var s: Float = 0
                        for c in 0..<channels { s += ptr[i * channels + c] }
                        mono[i] = s / Float(channels)
                    }
                }
            }
        } else if bits == 16 {
            let scale: Float = 1.0 / Float(Int16.max)
            if isNonInterleaved {
                let planeCount = abl.count
                for p in 0..<planeCount {
                    guard let ptr = abl[p].mData?.assumingMemoryBound(to: Int16.self) else { continue }
                    for i in 0..<frames {
                        mono[i] += Float(ptr[i]) * scale
                    }
                }
                if planeCount > 1 {
                    var inv = 1.0 / Float(planeCount)
                    vDSP_vsmul(mono, 1, &inv, &mono, 1, vDSP_Length(frames))
                }
            } else {
                let ptr = mData.assumingMemoryBound(to: Int16.self)
                if channels == 1 {
                    for i in 0..<frames { mono[i] = Float(ptr[i]) * scale }
                } else {
                    for i in 0..<frames {
                        var s: Float = 0
                        for c in 0..<channels { s += Float(ptr[i * channels + c]) * scale }
                        mono[i] = s / Float(channels)
                    }
                }
            }
        } else {
            return nil
        }

        return mono
    }

    nonisolated private static func floatsFromBlockBuffer(
        _ sampleBuffer: CMSampleBuffer,
        asbd: AudioStreamBasicDescription,
        channels: Int
    ) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer, length > 0 else { return nil }

        let bytesPerFrame = max(1, Int(asbd.mBytesPerFrame))
        let frameCount = length / bytesPerFrame
        guard frameCount > 0 else { return nil }

        var mono = [Float](repeating: 0, count: frameCount)
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let bits = Int(asbd.mBitsPerChannel)

        if isFloat && bits == 32 {
            dataPointer.withMemoryRebound(to: Float.self, capacity: frameCount * channels) { ptr in
                if channels == 1 {
                    for i in 0..<frameCount { mono[i] = ptr[i] }
                } else {
                    for i in 0..<frameCount {
                        var s: Float = 0
                        for c in 0..<channels { s += ptr[i * channels + c] }
                        mono[i] = s / Float(channels)
                    }
                }
            }
        } else if bits == 16 {
            dataPointer.withMemoryRebound(to: Int16.self, capacity: frameCount * channels) { ptr in
                let scale: Float = 1.0 / Float(Int16.max)
                if channels == 1 {
                    for i in 0..<frameCount { mono[i] = Float(ptr[i]) * scale }
                } else {
                    for i in 0..<frameCount {
                        var s: Float = 0
                        for c in 0..<channels { s += Float(ptr[i * channels + c]) * scale }
                        mono[i] = s / Float(channels)
                    }
                }
            }
        } else {
            return nil
        }
        return mono
    }
}
