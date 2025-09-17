//
//  AudioTranscriber.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import Foundation
import AVFoundation
import WhisperKit
import CoreAudio

@MainActor
class AudioTranscriber: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var whisperKit: WhisperKit?
    private var currentModel: String = "tiny" // 默认模型
    private var modelDownloaded: Bool = false // 标记模型是否已下载
    private var audioData: Data = Data() // 用于存储录音数据
    private var audioFormat: AVAudioFormat? // 存储音频格式信息
    private var isRealTimeTranscription = false // 标记是否启用实时转录
    private var selectedDeviceID: AudioDeviceID? // 存储选择的音频设备ID
    
    @Published var isRecording = false
    @Published var transcript = "点击开始录音..."
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = "准备下载模型..."
    
    // 音频设备相关属性
    @Published var audioDevices: [AudioDevice] = []
    @Published var selectedDeviceIndex = 0
    
    // 公开模型下载状态的访问方法
    var isModelDownloaded: Bool {
        return modelDownloaded
    }
    
    override init() {
        super.init()
        // macOS不需要设置音频会话
    }
    
    func setModel(_ model: String) {
        currentModel = model.lowercased()
        print("模型已设置为: \(currentModel)")
    }
    
    func enableRealTimeTranscription(_ enable: Bool) {
        isRealTimeTranscription = enable
    }
    
    func isModelAlreadyDownloaded() -> Bool {
        // 检查模型是否已下载
        let modelPath = getModelPath(for: currentModel)
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: modelPath)
    }
    
    private func getModelPath(for model: String) -> String {
        // 获取模型路径
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let modelPath = "\(documentsPath)/whisperkit-coreml/openai_whisper-\(model)"
        return modelPath
    }
    
    func checkAndDownloadModelIfNeeded() async -> Bool {
        // 检查模型是否已下载
        if isModelAlreadyDownloaded() {
            modelDownloaded = true
            return true
        }
        
        do {
            isDownloading = true
            downloadStatus = "正在检查 \(currentModel) 模型..."
            downloadProgress = 0.0
            
            // 使用WhisperKit的模型下载功能
            let progressHandler: (Progress) -> Void = { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                    self.downloadStatus = "正在下载 \(self.currentModel) 模型... \(Int(progress.fractionCompleted * 100))%"
                }
            }
            
            downloadStatus = "正在下载 \(currentModel) 模型..."
            
            // 下载模型
            _ = try await WhisperKit.download(
                variant: currentModel,
                progressCallback: progressHandler
            )
            
            isDownloading = false
            downloadStatus = "模型下载完成"
            modelDownloaded = true // 标记模型已下载
            return true
        } catch {
            print("模型下载失败: \(error)")
            isDownloading = false
            downloadStatus = "模型下载失败: \(error.localizedDescription)"
            return false
        }
    }
    
    func startRecording() {
        isRecording = true
        transcript = "正在录音..."
        audioData = Data() // 重置音频数据
        
        // 检查麦克风权限
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startRecordingWithPermission()
                } else {
                    self?.transcript = "麦克风权限被拒绝"
                    self?.isRecording = false
                }
            }
        }
    }
    
    private func startRecordingWithPermission() {
        // 初始化WhisperKit
        Task {
            // 检查模型是否已下载
            if !modelDownloaded {
                await MainActor.run {
                    self.transcript = "请先下载模型"
                    self.isRecording = false
                }
                return
            }
            
            do {
                // 根据选择的模型初始化WhisperKit
                let config = WhisperKitConfig(model: currentModel)
                whisperKit = try await WhisperKit(config)
                print("WhisperKit 初始化成功，使用模型: \(currentModel)")
            } catch {
                print("WhisperKit 初始化失败: \(error)")
                await MainActor.run {
                    self.transcript = "模型加载失败: \(error.localizedDescription)"
                    self.isRecording = false
                }
                return
            }
            
            // 设置音频引擎
            audioEngine = AVAudioEngine()
            
            guard let audioEngine = audioEngine else { return }
            
            // 获取输入节点
            let inputNode: AVAudioInputNode
            if let deviceID = selectedDeviceID {
                // 如果选择了特定设备，尝试使用它
                // 注意：AVAudioEngine 不直接支持选择特定的输入设备
                // 我们需要通过 AVAudioSession (在 iOS 中) 或 CoreAudio (在 macOS 中) 来实现
                // 这里我们仍然使用默认输入节点，但会在日志中记录选择的设备
                print("尝试使用音频设备: \(deviceID)")
                inputNode = audioEngine.inputNode
            } else {
                // 使用默认输入节点
                inputNode = audioEngine.inputNode
            }
            
            let bus = 0
            
            // 使用输入节点的输出格式，避免格式不匹配
            let inputFormat = inputNode.outputFormat(forBus: bus)
            audioFormat = inputFormat // 保存音频格式
            
            print("音频格式: \(inputFormat)")
            print("采样率: \(inputFormat.sampleRate)")
            print("声道数: \(inputFormat.channelCount)")
            print("位深度: \(inputFormat.settings[AVLinearPCMBitDepthKey] ?? "Unknown")")
            
            // 重置音频数据
            audioData = Data()
            
            // 创建一个与输入格式匹配的格式用于安装tap
            let tapFormat = AVAudioFormat(commonFormat: inputFormat.commonFormat, 
                                          sampleRate: inputFormat.sampleRate, 
                                          channels: inputFormat.channelCount, 
                                          interleaved: inputFormat.isInterleaved)
            
            // 安装抽头以捕获音频数据
            inputNode.installTap(onBus: bus, bufferSize: 1024, format: tapFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // 将音频数据转换为Data并追加
                let channelCount = Int(buffer.format.channelCount)
                let frameLength = Int(buffer.frameLength)
                
                // 打印调试信息
                DispatchQueue.main.async {
                    print("接收到音频数据: \(buffer.frameLength) 帧")
                    print("缓冲区大小: \(buffer.frameCapacity)")
                }
                
                // 获取音频数据
                if let audioData = self.audioBufferToData(buffer, channelCount: channelCount, frameLength: frameLength) {
                    DispatchQueue.main.async {
                        print("音频数据大小: \(audioData.count) 字节")
                        self.audioData.append(audioData)
                        
                        // 如果启用了实时转录并且有足够的数据，进行实时转录
                        if self.isRealTimeTranscription && self.audioData.count > Int(inputFormat.sampleRate) * 2 * 2 { // 至少2秒的数据
                            Task {
                                await self.performRealTimeTranscription()
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        print("无法获取音频数据")
                    }
                }
            }
            
            do {
                // 连接输入节点到主混音器，确保音频流通过
                audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: inputFormat)
                
                try audioEngine.start()
                print("音频录制已开始")
            } catch {
                print("无法启动音频引擎: \(error)")
                isRecording = false
                transcript = "录音启动失败: \(error.localizedDescription)"
            }
        }
    }
    
    // 将AVAudioPCMBuffer转换为Data
    private func audioBufferToData(_ buffer: AVAudioPCMBuffer, channelCount: Int, frameLength: Int) -> Data? {
        guard let channelData = buffer.floatChannelData else { 
            print("无法获取channelData")
            return nil 
        }
        
        // 检查数据有效性
        if frameLength == 0 {
            print("帧长度为0")
            return nil
        }
        
        // 打印缓冲区信息
        print("缓冲区信息: 帧长度=\(frameLength), 通道数=\(channelCount)")
        
        // 直接使用缓冲区数据，不需要转换
        let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)
        return data
    }
    
    func stopRecording() {
        isRecording = false
        
        guard let audioEngine = audioEngine else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        print("音频录制已停止")
        print("总音频数据大小: \(audioData.count) 字节")
        transcript = "录音已停止，正在处理..."
        
        // 处理音频数据
        processAudio()
    }
    
    // 实时转录方法
    private func performRealTimeTranscription() async {
        guard let whisperKit = whisperKit, isRecording else { return }
        
        // 创建临时文件进行转录
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("realtime.wav")
        
        do {
            try saveAudioDataToWAV(audioData, format: audioFormat, url: tempURL)
            
            // 使用WhisperKit进行转录
            let result = try await whisperKit.transcribe(audioPath: tempURL.path)
            
            await MainActor.run {
                if let results = result as? [TranscriptionResult], let firstResult = results.first {
                    // 更新转录文本
                    self.transcript = firstResult.text ?? "转录结果为空"
                } else if let text = result as? String {
                    // 如果结果直接是字符串
                    self.transcript = text.isEmpty ? "转录结果为空" : text
                } else {
                    // 尝试获取text属性
                    let text = (result as? NSObject)?.value(forKey: "text") as? String ?? "转录结果为空"
                    self.transcript = text
                }
                print("实时转录结果: \(self.transcript)")
            }
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("实时转录失败: \(error)")
        }
    }
    
    private func processAudio() {
        guard !audioData.isEmpty else {
            transcript = "没有录制到音频数据"
            return
        }
        
        // 将音频数据保存到临时文件
        Task {
            do {
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recording.wav")
                print("音频文件路径: \(tempURL.path)")
                try saveAudioDataToWAV(audioData, format: audioFormat, url: tempURL)
                
                // 检查保存的文件大小
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                if let fileSize = fileAttributes[.size] as? NSNumber {
                    print("保存的文件大小: \(fileSize) 字节")
                }
                
                // 检查文件是否存在且不为空
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    let fileData = try Data(contentsOf: tempURL)
                    print("实际文件大小: \(fileData.count) 字节")
                    
                    // 验证WAV文件头
                    if fileData.count >= 44 {
                        let header = fileData.subdata(in: 0..<44)
                        print("WAV文件头: \(header.map { String(format: "%02x", $0) }.joined(separator: " "))")
                    }
                }
                
                // 使用WhisperKit进行转录
                await transcribeAudio(audioFilePath: tempURL.path)
            } catch {
                print("音频处理失败: \(error)")
                await MainActor.run {
                    self.transcript = "音频处理失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveAudioDataToWAV(_ data: Data, format: AVAudioFormat?, url: URL) throws {
        // 如果没有格式信息，使用默认值
        let sampleRate = format?.sampleRate ?? 48000  // 使用实际的采样率（通常是48kHz）
        let channels = format?.channelCount ?? 1
        let bitDepth = 16 // 强制使用16位深度以兼容Whisper
        
        print("保存音频数据到WAV文件:")
        print("  数据大小: \(data.count) 字节")
        print("  采样率: \(sampleRate)")
        print("  声道数: \(channels)")
        print("  位深度: \(bitDepth)")
        
        // 将浮点数据转换为16位PCM数据
        let convertedData = convertFloatToPCM16(data)
        print("转换后数据大小: \(convertedData.count) 字节")
        
        // 创建WAV文件头
        let header = createWAVHeader(
            dataCount: convertedData.count,
            sampleRate: UInt32(sampleRate),
            channels: UInt16(channels),
            bitDepth: UInt16(bitDepth)
        )
        
        // 写入文件
        var fileData = Data(header)
        fileData.append(convertedData)
        
        // 确保目录存在
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        try fileData.write(to: url)
        print("音频文件已保存到: \(url.path)")
        print("文件总大小: \(fileData.count) 字节")
    }
    
    // 将浮点数据转换为16位PCM数据
    private func convertFloatToPCM16(_ floatData: Data) -> Data {
        // 计算浮点数的数量
        let floatCount = floatData.count / MemoryLayout<Float>.size
        
        // 创建一个新的Data对象来存储转换后的16位数据
        var int16Data = Data(capacity: floatCount * MemoryLayout<Int16>.size)
        
        // 逐个处理每个浮点数
        for i in 0..<floatCount {
            // 计算当前浮点数在数据中的位置
            let offset = i * MemoryLayout<Float>.size
            
            // 从数据中提取浮点数
            let floatBytes = floatData.subdata(in: offset..<offset + MemoryLayout<Float>.size)
            let float = floatBytes.withUnsafeBytes { (rawBufferPointer) -> Float in
                let bufferPointer = rawBufferPointer.bindMemory(to: Float.self)
                return bufferPointer.baseAddress!.pointee
            }
            
            // 将浮点数(-1.0到1.0)转换为16位整数(-32768到32767)
            let int16Value = Int16(clamping: Int32(float * 32767.0))
            
            // 将Int16值转换为字节并添加到结果数据中
            var value = int16Value
            let bytes = Data(bytes: &value, count: MemoryLayout<Int16>.size)
            int16Data.append(bytes)
        }
        
        return int16Data
    }
    
    // 创建WAV文件头
    private func createWAVHeader(dataCount: Int, sampleRate: UInt32, channels: UInt16, bitDepth: UInt16) -> Data {
        let headerSize = 44
        var header = Data(count: headerSize)
        
        // RIFF header
        header.replaceSubrange(0..<4, with: "RIFF".utf8)
        
        // File size (data count + 36)
        var fileSize: UInt32 = UInt32(dataCount + 36)
        header.replaceSubrange(4..<8, with: Data(bytes: &fileSize, count: 4))
        
        // WAVE header
        header.replaceSubrange(8..<12, with: "WAVE".utf8)
        
        // Format chunk marker
        header.replaceSubrange(12..<16, with: "fmt ".utf8)
        
        // Length of format data (16 for PCM)
        var formatLength: UInt32 = 16
        header.replaceSubrange(16..<20, with: Data(bytes: &formatLength, count: 4))
        
        // Type of format (1 for PCM)
        var formatType: UInt16 = 1
        header.replaceSubrange(20..<22, with: Data(bytes: &formatType, count: 2))
        
        // Number of channels
        var channelsVar: UInt16 = channels
        header.replaceSubrange(22..<24, with: Data(bytes: &channelsVar, count: 2))
        
        // Sample rate
        var sampleRateVar: UInt32 = sampleRate
        header.replaceSubrange(24..<28, with: Data(bytes: &sampleRateVar, count: 4))
        
        // Byte rate (sample rate * bits per sample * channels / 8)
        var byteRate: UInt32 = sampleRate * UInt32(bitDepth) * UInt32(channels) / 8
        header.replaceSubrange(28..<32, with: Data(bytes: &byteRate, count: 4))
        
        // Block align (bits per sample * channels / 8)
        var blockAlign: UInt16 = bitDepth * channels / 8
        header.replaceSubrange(32..<34, with: Data(bytes: &blockAlign, count: 2))
        
        // Bits per sample
        var bitsPerSample: UInt16 = bitDepth
        header.replaceSubrange(34..<36, with: Data(bytes: &bitsPerSample, count: 2))
        
        // Data chunk header
        header.replaceSubrange(36..<40, with: "data".utf8)
        
        // Data chunk size
        var dataSize: UInt32 = UInt32(dataCount)
        header.replaceSubrange(40..<44, with: Data(bytes: &dataSize, count: 4))
        
        return header
    }
    
    func transcribeAudio(audioFilePath: String) async {
        guard let whisperKit = whisperKit else {
            print("WhisperKit 未初始化")
            return
        }
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: audioFilePath) {
            print("音频文件不存在: \(audioFilePath)")
            await MainActor.run {
                self.transcript = "音频文件不存在"
            }
            return
        }
        
        do {
            print("开始转录音频文件: \(audioFilePath)")
            let result = try await whisperKit.transcribe(audioPath: audioFilePath)
            print("转录完成")
            
            await MainActor.run {
                if let results = result as? [TranscriptionResult], let firstResult = results.first {
                    // 获取转录文本
                    self.transcript = firstResult.text ?? "转录结果为空"
                } else if let text = result as? String {
                    // 如果结果直接是字符串
                    self.transcript = text.isEmpty ? "转录结果为空" : text
                } else {
                    // 尝试获取text属性
                    let text = (result as? NSObject)?.value(forKey: "text") as? String ?? "转录结果为空"
                    self.transcript = text
                }
                print("转录结果: \(self.transcript)")
            }
        } catch {
            print("转录失败: \(error)")
            await MainActor.run {
                self.transcript = "转录失败: \(error.localizedDescription)"
            }
        }
    }
    
    // 音频设备结构
    struct AudioDevice {
        let id: AudioDeviceID
        let name: String
    }
    
    // 获取可用的音频输入设备
    func getAvailableAudioDevices() {
        var devices: [AudioDevice] = []
        
        // 获取默认输入设备
        var defaultDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )
        
        if status == noErr {
            let deviceName = getDeviceName(deviceID: defaultDeviceID)
            devices.append(AudioDevice(id: defaultDeviceID, name: "默认设备: \(deviceName)"))
        }
        
        // 获取所有音频设备
        var deviceCount = UInt32(0)
        address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        propertySize = 0
        var status2 = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        if status2 != noErr { return }
        
        deviceCount = propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(deviceCount))
        status2 = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        if status2 != noErr { return }
        
        // 过滤出输入设备
        for deviceID in deviceIDs {
            var streamCount = UInt32(0)
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            propertySize = 0
            status2 = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &propertySize)
            if status2 != noErr { continue }
            
            streamCount = propertySize / UInt32(MemoryLayout<AudioObjectID>.size)
            if streamCount > 0 {
                let deviceName = getDeviceName(deviceID: deviceID)
                devices.append(AudioDevice(id: deviceID, name: deviceName))
            }
        }
        
        DispatchQueue.main.async {
            self.audioDevices = devices
        }
    }
    
    // 获取设备名称
    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var deviceName = ""
        var propertySize = UInt32(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        propertySize = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize)
        if status != noErr { return "未知设备" }
        
        var deviceNameCFString: CFString?
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &deviceNameCFString)
        if status == noErr, let name = deviceNameCFString {
            deviceName = name as String
        } else {
            deviceName = "未知设备"
        }
        
        return deviceName
    }
    
    // 设置选择的音频设备
    func setSelectedDevice(index: Int) {
        guard index < audioDevices.count else { return }
        selectedDeviceIndex = index
        selectedDeviceID = audioDevices[index].id
    }
}
