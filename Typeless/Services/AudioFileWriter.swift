import Foundation
import AVFoundation

// MARK: - Audio File Writer

final class AudioFileWriter {
    // MARK: - WAV Creation

    /// Save audio data to a WAV file
    func saveAudioDataToWAV(_ data: Data, format: AVAudioFormat?, url: URL) throws {
        let sampleRate = format?.sampleRate ?? AppConstants.Audio.defaultSampleRate
        let channels = AppConstants.Audio.defaultChannels
        let bitDepth = AppConstants.Audio.defaultBitDepth

        #if DEBUG
        print("Saving audio to WAV: \(data.count) bytes, \(sampleRate)Hz, \(channels)ch, \(bitDepth)bit")
        #endif

        let convertedData = convertFloatToPCM16(data)
        let header = createWAVHeader(
            dataCount: convertedData.count,
            sampleRate: UInt32(sampleRate),
            channels: channels,
            bitDepth: bitDepth
        )

        var fileData = Data(header)
        fileData.append(convertedData)

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try fileData.write(to: url)

        #if DEBUG
        print("WAV file saved: \(url.path), size: \(fileData.count) bytes")
        #endif
    }

    // MARK: - PCM Conversion

    /// Convert Float32 audio data to 16-bit PCM
    func convertFloatToPCM16(_ floatData: Data) -> Data {
        guard !floatData.isEmpty else {
            return Data()
        }

        let floatCount = floatData.count / MemoryLayout<Float>.size
        var int16Data = Data(capacity: floatCount * MemoryLayout<Int16>.size)

        for i in 0..<floatCount {
            let offset = i * MemoryLayout<Float>.size
            guard offset + MemoryLayout<Float>.size <= floatData.count else { break }

            let floatBytes = floatData.subdata(in: offset..<offset + MemoryLayout<Float>.size)
            let float = floatBytes.withUnsafeBytes { (rawBufferPointer) -> Float in
                let bufferPointer = rawBufferPointer.bindMemory(to: Float.self)
                return bufferPointer.baseAddress!.pointee
            }

            let clampedFloat = min(max(float, -1.0), 1.0)
            let int16Value = Int16(clamping: Int32(clampedFloat * 32767.0))

            var value = int16Value
            let bytes = Data(bytes: &value, count: MemoryLayout<Int16>.size)
            int16Data.append(bytes)
        }

        return int16Data
    }

    // MARK: - WAV Header

    /// Create a standard 44-byte WAV file header
    func createWAVHeader(dataCount: Int, sampleRate: UInt32, channels: UInt16, bitDepth: UInt16) -> Data {
        let headerSize = 44
        var header = Data(count: headerSize)

        // RIFF header
        header.replaceSubrange(0..<4, with: "RIFF".utf8)

        // File size
        var fileSize: UInt32 = UInt32(dataCount + 36)
        header.replaceSubrange(4..<8, with: Data(bytes: &fileSize, count: 4))

        // WAVE header
        header.replaceSubrange(8..<12, with: "WAVE".utf8)

        // Format chunk
        header.replaceSubrange(12..<16, with: "fmt ".utf8)

        var formatLength: UInt32 = 16
        header.replaceSubrange(16..<20, with: Data(bytes: &formatLength, count: 4))

        var formatType: UInt16 = 1 // PCM
        header.replaceSubrange(20..<22, with: Data(bytes: &formatType, count: 2))

        var channelsVar: UInt16 = channels
        header.replaceSubrange(22..<24, with: Data(bytes: &channelsVar, count: 2))

        var sampleRateVar: UInt32 = sampleRate
        header.replaceSubrange(24..<28, with: Data(bytes: &sampleRateVar, count: 4))

        var byteRate: UInt32 = sampleRate * UInt32(bitDepth) * UInt32(channels) / 8
        header.replaceSubrange(28..<32, with: Data(bytes: &byteRate, count: 4))

        var blockAlign: UInt16 = bitDepth * channels / 8
        header.replaceSubrange(32..<34, with: Data(bytes: &blockAlign, count: 2))

        var bitsPerSample: UInt16 = bitDepth
        header.replaceSubrange(34..<36, with: Data(bytes: &bitsPerSample, count: 2))

        // Data chunk
        header.replaceSubrange(36..<40, with: "data".utf8)

        var dataSize: UInt32 = UInt32(dataCount)
        header.replaceSubrange(40..<44, with: Data(bytes: &dataSize, count: 4))

        return header
    }

    // MARK: - Temp File Management

    /// Create a secure temporary file URL
    func createSecureTempFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vocaltext")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileName = "recording_\(UUID().uuidString).wav"
        return tempDir.appendingPathComponent(fileName)
    }

    /// Clean up temporary files
    func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("vocaltext")
        guard FileManager.default.fileExists(atPath: tempDir.path) else { return }

        do {
            try FileManager.default.removeItem(at: tempDir)
            #if DEBUG
            print("✅ Cleaned up temp directory: \(tempDir.path)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to clean up temp directory: \(error)")
            #endif
        }
    }
}