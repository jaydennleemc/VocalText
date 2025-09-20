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
    private var selectedDeviceID: AudioDeviceID? // 存储选择的音频设备ID
    private var deviceMonitoringTimer: Timer? // 用于存储设备监控定时器
    
    @Published var isRecording = false
    @Published var isTranscribing = false // 添加转录状态
    @Published var transcript = "點擊開始錄音..."
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = "準備下載模型..."
    @Published var volumeLevel: Double = 0.0 // 添加音量级别属性
    
    // 音频设备相关属性
    @Published var audioDevices: [AudioDevice] = []
    @Published var selectedDeviceIndex = 0
    
    // 公开模型下载状态的访问方法
    var isModelDownloaded: Bool {
        return modelDownloaded
    }
    
    override init() {
        super.init()
        // macOS上也需要正确配置AVAudioSession以避免HALC错误
        setupAudioSession()
        // 开始监听音频设备变化
        startMonitoringAudioDevices()
    }
    
    private func setupAudioSession() {
        // 在macOS上，正确配置AVAudioSession以避免HALC错误
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // 在iOS上使用playAndRecord类别以支持录音和播放
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            print("音頻會話設置完成")
        } catch {
            print("音頻會話設置失敗: \(error)")
        }
        #endif
        // macOS上不需要特别配置AVAudioSession
        print("音頻會話設置完成")
    }
    
    // 监听音频设备变化
    private func startMonitoringAudioDevices() {
        // 使用定时器定期检查设备变化
        deviceMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.getAvailableAudioDevices()
            }
        }
        
        // 初始获取设备列表
        getAvailableAudioDevices()
    }
    
    func setModel(_ model: String) {
        currentModel = model.lowercased()
        print("模型已設置為: \(currentModel)")
    }
    
    func isModelAlreadyDownloaded(model: String) -> Bool {
        // 检查指定模型是否已下载
        let modelPath = getModelPath(for: model)
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: modelPath)
        print("模型 \(model) 是否存在: \(exists) at path: \(modelPath)")
        
        // 检查模型目录中是否包含必要的文件
        if exists {
            let requiredFiles = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "Config.json"]
            for file in requiredFiles {
                let filePath = "\(modelPath)/\(file)"
                if !fileManager.fileExists(atPath: filePath) {
                    print("模型 \(model) 缺少必要文件: \(file)")
                    return false
                }
            }
            print("模型 \(model) 已完整下載")
            return true
        }
        
        return false
    }
    
    func isModelAlreadyDownloaded() -> Bool {
        // 检查当前模型是否已下载
        return isModelAlreadyDownloaded(model: currentModel)
    }
    
    private func getModelPath(for model: String) -> String {
        // 获取模型路径
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let modelPath = "\(documentsPath)/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(model)"
        print("檢查模型路徑: \(modelPath)")
        return modelPath
    }
    
    func checkAndDownloadModelIfNeeded() async -> Bool {
        // 检查模型是否已下载
        if isModelAlreadyDownloaded(model: currentModel) {
            modelDownloaded = true
            return true
        }
        
        do {
            isDownloading = true
            downloadStatus = "正在檢查 \(currentModel) 模型..."
            downloadProgress = 0.0
            
            // 发送开始下载通知
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadStarted"), object: nil)
            
            // 使用WhisperKit的模型下载功能
            let progressHandler: (Progress) -> Void = { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                    self.downloadStatus = "正在下載 \(self.currentModel) 模型... \(Int(progress.fractionCompleted * 100))%"
                }
            }
            
            downloadStatus = "正在下載 \(currentModel) 模型..."
            
            // 下载模型
            _ = try await WhisperKit.download(
                variant: currentModel,
                progressCallback: progressHandler
            )
            
            isDownloading = false
            downloadStatus = "模型下載完成"
            modelDownloaded = true // 标记模型已下载
            
            // 发送下载完成通知
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadFinished"), object: nil)
            
            // 添加调试日志
            print("模型下載完成，modelDownloaded = \(modelDownloaded)")
            return true
        } catch let error as NSError {
            print("模型下載失敗: \(error)")
            isDownloading = false
            downloadStatus = "模型下載失敗: \(error.localizedDescription)"
            modelDownloaded = false // 确保标记为未下载
            
            // 发送下载完成通知（即使是失败的情况）
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadFinished"), object: nil)
            
            // 提供更详细的错误信息
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    downloadStatus = "模型下載失敗: 無網絡連接"
                case NSURLErrorTimedOut:
                    downloadStatus = "模型下載失敗: 連接超時"
                case NSURLErrorCannotFindHost:
                    downloadStatus = "模型下載失敗: 無法找到服務器"
                default:
                    downloadStatus = "模型下載失敗: 網絡錯誤 (\(error.localizedDescription))"
                }
            } else {
                downloadStatus = "模型下載失敗: \(error.localizedDescription)"
            }
            
            return false
        } catch {
            print("模型下載失敗: \(error)")
            isDownloading = false
            downloadStatus = "模型下載失敗: 未知錯誤"
            modelDownloaded = false // 确保标记为未下载
            
            // 发送下载完成通知（即使是失败的情况）
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadFinished"), object: nil)
            
            return false
        }
    }
    
    func startRecording() {
        // 检查是否有音频输入设备
        if !hasAvailableAudioInputDevices() {
            transcript = "未檢測到音頻輸入設備，請連接麥克風或其他音頻輸入設備"
            return
        }
        
        isRecording = true
        transcript = "正在錄音..."
        audioData = Data() // 重置音频数据
        
        // 发送录音开始通知
        NotificationCenter.default.post(name: Notification.Name("RecordingStarted"), object: nil)
        
        // 检查麦克风权限
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    // 先检查模型是否已下载
                    guard let self = self else { return }
                    
                    // 检查模型是否已下载（重新检查以确保状态正确）
                    if !self.isModelAlreadyDownloaded() {
                        self.transcript = "模型未下載，請先下載模型"
                        self.isRecording = false
                        // 发送录音停止通知
                        NotificationCenter.default.post(name: Notification.Name("RecordingStopped"), object: nil)
                        return
                    }
                    
                    // 如果WhisperKit已经初始化，直接开始录音
                    if self.whisperKit != nil {
                        self.startAudioEngine()
                    } else {
                        // 初始化WhisperKit然后开始录音
                        Task {
                            await self.initializeWhisperKitAndStartRecording()
                        }
                    }
                } else {
                    self?.transcript = "麥克風權限被拒絕"
                    self?.isRecording = false
                    // 发送录音停止通知
                    NotificationCenter.default.post(name: Notification.Name("RecordingStopped"), object: nil)
                }
            }
        }
    }
    
    private var selectedLanguage: String = "zh" // 默认语言为中文
    private var isWhisperKitPreloading = false // 标记WhisperKit是否正在预加载
    
    func setLanguage(_ language: String) {
        selectedLanguage = language
        print("語言已設置為: \(selectedLanguage)")
        
        // 添加调试信息，查看 WhisperKit 是否支持语言设置
        if let whisperKit = whisperKit {
            // 尝试查看 whisperKit 是否有语言相关的属性或方法
            print("WhisperKit 實例: \(whisperKit)")
        }
    }
    
    // 预加载WhisperKit以减少首次录音延迟
    func preloadWhisperKit() async {
        // 避免重复预加载
        guard !isWhisperKitPreloading && whisperKit == nil else { return }
        
        isWhisperKitPreloading = true
        print("開始預加載WhisperKit...")
        
        do {
            // 根据选择的模型初始化WhisperKit
            var config = WhisperKitConfig(model: currentModel)
            let loadedWhisperKit = try await WhisperKit(config)
            
            await MainActor.run {
                self.whisperKit = loadedWhisperKit
                self.isWhisperKitPreloading = false
                print("WhisperKit 預加載完成")
            }
        } catch {
            print("WhisperKit 預加載失敗: \(error)")
            await MainActor.run {
                self.isWhisperKitPreloading = false
            }
        }
    }
    
    private func initializeWhisperKitAndStartRecording() async {
        // 如果WhisperKit已经初始化，直接开始录音
        if whisperKit != nil {
            await MainActor.run {
                self.startAudioEngine()
            }
            return
        }
        
        // 初始化WhisperKit
        do {
            // 根据选择的模型初始化WhisperKit
            // 尝试在配置中设置语言（如果 WhisperKit 支持）
            var config = WhisperKitConfig(model: currentModel)
            
            // 注意：WhisperKitConfig 可能不直接支持 language 参数
            // 我们需要在转录时指定语言
            whisperKit = try await WhisperKit(config)
            print("WhisperKit 初始化成功，使用模型: \(currentModel)")
            
            // 初始化完成后开始录音
            await MainActor.run {
                self.startAudioEngine()
            }
        } catch {
            print("WhisperKit 初始化失敗: \(error)")
            await MainActor.run {
                self.transcript = "模型加載失敗: \(error.localizedDescription)"
                self.isRecording = false
            }
        }
    }
    
    private func startAudioEngine() {
        // 如果音频引擎已经在运行，先停止它
        if let existingEngine = audioEngine, existingEngine.isRunning {
            existingEngine.stop()
            // 移除所有tap
            if existingEngine.inputNode.numberOfInputs > 0 {
                existingEngine.inputNode.removeTap(onBus: 0)
            }
        }
        
        // 如果音频引擎已经存在，先重置它
        if audioEngine != nil {
            audioEngine = nil
        }
        
        // 设置音频引擎
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { 
            transcript = "音頻引擎初始化失敗"
            isRecording = false
            return
        }
        
        // 获取输入节点
        let inputNode = audioEngine.inputNode
        let bus = 0
        
        // 使用输入节点的输出格式，避免格式不匹配
        let inputFormat = inputNode.outputFormat(forBus: bus)
        audioFormat = inputFormat // 保存音频格式
        
        print("音頻格式: \(inputFormat)")
        print("採樣率: \(inputFormat.sampleRate)")
        print("聲道數: \(inputFormat.channelCount)")
        print("位深度: \(inputFormat.settings[AVLinearPCMBitDepthKey] ?? "Unknown")")
        
        // 重置音频数据
        audioData = Data()
        
        // 安装抽头以捕获音频数据
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 将音频数据转换为Data并追加
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            
            // 计算音量级别
            let volume = self.calculateVolume(from: buffer)
            
            // 打印调试信息
            DispatchQueue.main.async {
                print("接收到音頻數據: \(buffer.frameLength) 幀, 音量: \(volume)")
                self.volumeLevel = volume // 更新音量级别
            }
            
            // 获取音频数据
            if let audioData = self.audioBufferToData(buffer, channelCount: channelCount, frameLength: frameLength) {
                DispatchQueue.main.async {
                    print("音頻數據大小: \(audioData.count) 字節")
                    self.audioData.append(audioData)
                }
            } else {
                DispatchQueue.main.async {
                    print("无法获取音频数据")
                }
            }
        }
        
        // 断开输入节点与主混音器的连接以避免音频反馈
        audioEngine.disconnectNodeInput(audioEngine.mainMixerNode)
        
        do {
            // 准备并启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            print("音频录制已开始")
        } catch {
            print("无法启动音频引擎: \(error)")
            isRecording = false
            transcript = "錄音啟動失敗: \(error.localizedDescription)"
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
        
        // 计算单声道数据大小（我们只处理第一个声道）
        let byteSize = frameLength * MemoryLayout<Float>.size
        
        // 创建包含单声道数据的Data对象
        let data = Data(bytes: channelData[0], count: byteSize)
        return data
    }
    
    // 计算音量级别
    private func calculateVolume(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return 0.0 }
        
        let data = channelData[0]
        var sum: Double = 0.0
        
        // 计算均方根(RMS)音量
        for i in 0..<frameLength {
            let sample = data[i]
            sum += Double(sample * sample)
        }
        
        let mean = sum / Double(frameLength)
        let rms = sqrt(mean)
        
        // 将RMS值转换为分贝
        let db = 20 * log10(rms)
        
        // 将分贝值映射到0-1范围，-80dB为最小值，-10dB为最大值
        let minDB: Double = -80.0
        let maxDB: Double = -10.0
        var level = (db - minDB) / (maxDB - minDB)
        
        // 确保级别在0-1范围内
        level = max(0.0, min(1.0, level))
        
        // 添加一些增强效果，使音量变化更明显
        // 使用平方值和缩放使变化更明显
        level = level * level * 2.0
        level = min(1.0, level) // 确保不超过1.0
        
        return level
    }
    
    func stopRecording() {
        isRecording = false
        
        // 发送录音停止通知
        NotificationCenter.default.post(name: Notification.Name("RecordingStopped"), object: nil)
        
        guard let audioEngine = audioEngine else { 
            transcript = "音頻引擎未初始化"
            return 
        }
        
        // 停止音频引擎
        audioEngine.stop()
        
        // 移除所有tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 重置音频引擎
        self.audioEngine = nil
        
        print("音頻錄製已停止")
        print("總音頻數據大小: \(audioData.count) 字節")
        transcript = "錄音已停止，正在處理..."
        
        // 只有在有音频数据时才处理
        if !audioData.isEmpty {
            // 处理音频数据
            processAudio()
        } else {
            transcript = "沒有錄製到音頻數據"
        }
    }
    
    private func processAudio() {
        guard !audioData.isEmpty else {
            transcript = "沒有錄製到音頻數據"
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
                    self.transcript = "音頻處理失敗: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveAudioDataToWAV(_ data: Data, format: AVAudioFormat?, url: URL) throws {
        // 使用输入的音频格式信息，如果不可用则使用默认值
        let sampleRate = format?.sampleRate ?? 44100  // 使用实际的采样率
        let channels = 1  // 强制使用单声道以确保兼容性
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
        
        // 删除已存在的文件
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        try fileData.write(to: url)
        print("音频文件已保存到: \(url.path)")
        print("文件总大小: \(fileData.count) 字节")
        
        // 验证文件是否正确创建
        if FileManager.default.fileExists(atPath: url.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            print("验证文件大小: \(attrs[.size] ?? "Unknown") 字节")
        }
    }
    
    // 将浮点数据转换为16位PCM数据
    private func convertFloatToPCM16(_ floatData: Data) -> Data {
        // 如果数据为空，返回空数据
        guard !floatData.isEmpty else {
            print("输入数据为空")
            return Data()
        }
        
        // 计算浮点数的数量
        let floatCount = floatData.count / MemoryLayout<Float>.size
        
        // 检查数据大小是否正确
        if floatData.count % MemoryLayout<Float>.size != 0 {
            print("警告: 数据大小不是Float大小的整数倍")
        }
        
        // 创建一个新的Data对象来存储转换后的16位数据
        var int16Data = Data(capacity: floatCount * MemoryLayout<Int16>.size)
        
        // 逐个处理每个浮点数
        for i in 0..<floatCount {
            // 计算当前浮点数在数据中的位置
            let offset = i * MemoryLayout<Float>.size
            
            // 确保不会越界
            if offset + MemoryLayout<Float>.size > floatData.count {
                print("警告: 数据越界 at index \(i)")
                break
            }
            
            // 从数据中提取浮点数
            let floatBytes = floatData.subdata(in: offset..<offset + MemoryLayout<Float>.size)
            let float = floatBytes.withUnsafeBytes { (rawBufferPointer) -> Float in
                let bufferPointer = rawBufferPointer.bindMemory(to: Float.self)
                return bufferPointer.baseAddress!.pointee
            }
            
            // 将浮点数(-1.0到1.0)转换为16位整数(-32768到32767)
            // 添加边界检查
            let clampedFloat = min(max(float, -1.0), 1.0)
            let int16Value = Int16(clamping: Int32(clampedFloat * 32767.0))
            
            // 将Int16值转换为字节并添加到结果数据中
            var value = int16Value
            let bytes = Data(bytes: &value, count: MemoryLayout<Int16>.size)
            int16Data.append(bytes)
        }
        
        print("转换完成: \(floatCount) 个浮点数 -> \(int16Data.count) 字节")
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
        // 设置转录状态为进行中
        await MainActor.run {
            self.isTranscribing = true
            // 发送转录开始通知
            NotificationCenter.default.post(name: Notification.Name("TranscribingStarted"), object: nil)
        }
        
        defer {
            // 确保在方法结束时将转录状态设为false
            Task { @MainActor in
                self.isTranscribing = false
                // 发送转录结束通知
                NotificationCenter.default.post(name: Notification.Name("TranscribingStopped"), object: nil)
            }
        }
        
        guard let whisperKit = whisperKit else {
            print("WhisperKit 未初始化")
            await MainActor.run {
                self.transcript = "模型未正確加載，請重新下載模型"
            }
            return
        }
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: audioFilePath) {
            print("音频文件不存在: \(audioFilePath)")
            await MainActor.run {
                self.transcript = "音頻文件不存在"
            }
            return
        }
        
        // 检查文件大小
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioFilePath)
            if let fileSize = fileAttributes[.size] as? NSNumber {
                print("轉錄文件大小: \(fileSize) 字節")
                if fileSize.intValue == 0 {
                    await MainActor.run {
                        self.transcript = "音頻文件為空"
                    }
                    return
                }
            }
        } catch {
            print("無法獲取文件信息: \(error)")
        }
        
        do {
            print("開始轉錄音頻文件: \(audioFilePath)")
            
            // 使用 DecodingOptions 配置语言
            let decodingOptions = DecodingOptions(
                language: selectedLanguage, // 使用设置的语言代码
                temperature: 0.0,
                sampleLength: 224
            )
            
            print("使用語言: \(selectedLanguage)")
            
            // 调用 transcribe 方法并传入解码选项
            let result = try await whisperKit.transcribe(
                audioPath: audioFilePath,
                decodeOptions: decodingOptions
            )
            
            print("轉錄完成")
            
            await MainActor.run {
                // 处理转录结果
                var extractedText = "轉錄結果為空"
                
                if let results = result as? [TranscriptionResult] {
                    // 如果是TranscriptionResult数组
                    if let firstResult = results.first {
                        extractedText = firstResult.text ?? "轉錄結果為空"
                    }
                } else if let textResults = result as? [String] {
                    // 如果是字符串数组
                    if let firstText = textResults.first {
                        extractedText = firstText.isEmpty ? "轉錄結果為空" : firstText
                    }
                } else if let singleText = result as? String {
                    // 如果是单个字符串
                    extractedText = singleText.isEmpty ? "轉錄結果為空" : singleText
                } else {
                    // 尝试获取text属性
                    if let text = (result as? NSObject)?.value(forKey: "text") as? String {
                        extractedText = text.isEmpty ? "轉錄結果為空" : text
                    }
                }
                
                self.transcript = extractedText
                print("轉錄結果: \(extractedText)")
            }
        } catch {
            print("转录失败: \(error)")
            await MainActor.run {
                self.transcript = "轉錄失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // 音频设备结构
    struct AudioDevice {
        let id: AudioDeviceID
        let name: String
    }
    
    // 检查是否有可用的音频输入设备
    func hasAvailableAudioInputDevices() -> Bool {
        let devices = getAvailableAudioDevicesSync()
        // 过滤掉"未知设备"等无效设备
        let validDevices = devices.filter { device in
            return device.name != "未知设备" && !device.name.isEmpty
        }
        return !validDevices.isEmpty
    }
    
    // 同步获取可用的音频输入设备
    private func getAvailableAudioDevicesSync() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // 获取所有音频设备
        var deviceCount = UInt32(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize = UInt32(0)
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        if status != noErr { return devices }
        
        deviceCount = propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(deviceCount))
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        if status != noErr { return devices }
        
        // 过滤出输入设备
        for deviceID in deviceIDs {
            var streamCount = UInt32(0)
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            propertySize = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &propertySize)
            if status != noErr { continue }
            
            streamCount = propertySize / UInt32(MemoryLayout<AudioObjectID>.size)
            if streamCount > 0 {
                let deviceName = getDeviceName(deviceID: deviceID)
                // 只添加有效的设备（不是"未知设备"且名称不为空）
                if deviceName != "未知设备" && !deviceName.isEmpty {
                    devices.append(AudioDevice(id: deviceID, name: deviceName))
                }
            }
        }
        
        return devices
    }
    
    // 获取可用的音频输入设备
    func getAvailableAudioDevices() {
        let devices = getAvailableAudioDevicesSync()
        
        DispatchQueue.main.async {
            let oldDeviceCount = self.audioDevices.count
            self.audioDevices = devices
            
            // 如果设备数量发生变化，发送通知
            if oldDeviceCount != devices.count {
                NotificationCenter.default.post(name: Notification.Name("AudioDevicesChanged"), object: nil)
            }
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
        guard index < audioDevices.count else { 
            print("无效的设备索引: \(index), 设备数量: \(audioDevices.count)")
            return 
        }
        selectedDeviceIndex = index
        selectedDeviceID = audioDevices[index].id
        print("已选择设备索引: \(index), 设备ID: \(audioDevices[index].id), 设备名称: \(audioDevices[index].name)")
        UserDefaults.standard.set(index, forKey: "SelectedDeviceIndex")
    }
    
    // 移除监听器
    deinit {
        deviceMonitoringTimer?.invalidate()
        deviceMonitoringTimer = nil
    }
}
