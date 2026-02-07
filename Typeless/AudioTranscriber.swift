//
//  AudioTranscriber.swift
//  Typeless
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
    private var recordingTimer: Timer? // 用于存储录音计时器

    // 临时文件管理
    private var audioFileURL: URL?
    private var audioWriter: AVAudioFile?

    #if DEBUG
    private var memoryMonitorTimer: Timer?
    private var baselineMemory: Double = 0.0
    #endif
    
    @Published var isRecording = false
    @Published var isTranscribing = false // 添加转录状态
    @Published var transcript = NSLocalizedString("recording.state.ready", comment: "Ready to record")
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = NSLocalizedString("model.status.preparing", comment: "Preparing to download model")
    @Published var volumeLevel: Double = 0.0 // 添加音量级别属性
    @Published var recordingTime: TimeInterval = 0.0 // 添加录音时间属性
    
    // 音频设备相关属性
    @Published var audioDevices: [AudioDevice] = []
    @Published var selectedDeviceIndex = 0
    
    // 公开模型下载状态的访问方法
    var isModelDownloaded: Bool {
        return modelDownloaded
    }

    var delegate: AudioTranscriberDelegate?

    var delegate: AudioTranscriberDelegate?
    
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
            #if DEBUG
            #if DEBUG
            print("音頻會話設置完成")
            #endif
            #endif
        } catch {
            #if DEBUG
            #if DEBUG
            print("音頻會話設置失敗: \(error)")
            #endif
            #endif
        }
        #endif
        // macOS上不需要特别配置AVAudioSession
        #if DEBUG
        #if DEBUG
        print("音頻會話設置完成")
        #endif
        #endif
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
        #if DEBUG
        #if DEBUG
        print("模型已設置為: \(currentModel)")
        #endif
        #endif
    }
    
    func isModelAlreadyDownloaded(model: String) -> Bool {
        // 检查指定模型是否已下载
        let modelPath = getModelPath(for: model)
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: modelPath)
        #if DEBUG
        #if DEBUG
        print("模型 \(model) 是否存在: \(exists) at path: \(modelPath)")
        #endif
        #endif
        
        // 检查模型目录中是否包含必要的文件
        if exists {
            let requiredFiles = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "Config.json"]
            for file in requiredFiles {
                let filePath = "\(modelPath)/\(file)"
                if !fileManager.fileExists(atPath: filePath) {
                    #if DEBUG
                    #if DEBUG
                    print("模型 \(model) 缺少必要文件: \(file)")
                    #endif
                    #endif
                    return false
                }
            }
            #if DEBUG
            #if DEBUG
            print("模型 \(model) 已完整下載")
            #endif
            #endif
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
        #if DEBUG
        #if DEBUG
        print("檢查模型路徑: \(modelPath)")
        #endif
        #endif
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
            downloadStatus = String(format: NSLocalizedString("model.status.checking", comment: "Checking model"), currentModel)
            downloadProgress = 0.0
            
            // 发送开始下载通知
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadStarted"), object: nil)
            
            // 使用WhisperKit的模型下载功能
            let progressHandler: (Progress) -> Void = { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                    self.downloadStatus = String(format: NSLocalizedString("model.status.downloading", comment: "Downloading model"), self.currentModel, progress.fractionCompleted * 100)
                }
            }
            
            downloadStatus = String(format: NSLocalizedString("model.status.downloading", comment: "Downloading model"), currentModel, 0.0)
            
            // 下载模型
            _ = try await WhisperKit.download(
                variant: currentModel,
                progressCallback: progressHandler
            )
            
            isDownloading = false
            downloadStatus = NSLocalizedString("model.status.downloaded", comment: "Model downloaded successfully")
            modelDownloaded = true // 标记模型已下载
            
            // 发送下载完成通知
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadFinished"), object: nil)
            
            // 添加调试日志
            #if DEBUG
            #if DEBUG
            print("模型下載完成，modelDownloaded = \(modelDownloaded)")
            #endif
            #endif
            return true
        } catch let error as NSError {
            #if DEBUG
            #if DEBUG
            print("模型下載失敗: \(error)")
            #endif
            #endif
            isDownloading = false
            downloadStatus = String(format: NSLocalizedString("model.status.download.failed", comment: "Model download failed"), error.localizedDescription)
            modelDownloaded = false // 确保标记为未下载


            // 发送下载完成通知（即使是失败的情况）
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadFinished"), object: nil)

            // 提供更详细的错误信息并通过delegate报告
            let typelessError: TypelessError
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    downloadStatus = NSLocalizedString("error.network.notConnected", comment: "No internet connection")
                    typelessError = .networkNotConnected
                case NSURLErrorTimedOut:
                    downloadStatus = NSLocalizedString("error.network.timeout", comment: "Connection timeout")
                    typelessError = .networkTimeout
                case NSURLErrorCannotFindHost:
                    downloadStatus = NSLocalizedString("error.network.serverNotFound", comment: "Server not found")
                    typelessError = .networkServerNotFound
                default:
                    downloadStatus = String(format: NSLocalizedString("error.network.generic", comment: "Network error"), error.localizedDescription)
                    typelessError = .networkGeneric(underlying: error)
                }
            } else {
                downloadStatus = String(format: NSLocalizedString("model.status.download.failed", comment: "Model download failed"), error.localizedDescription)
                typelessError = .modelDownloadFailed(reason: error.localizedDescription)
            }

            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: typelessError)

            return false
        } catch {
            #if DEBUG
            #if DEBUG
            print("模型下載失敗: \(error)")
            #endif
            #endif
            isDownloading = false
            downloadStatus = NSLocalizedString("error.generic.unknown", comment: "Unknown error")
            modelDownloaded = false // 确保标记为未下载


            // 发送下载完成通知（即使是失败的情况）
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadFinished"), object: nil)

            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .unknownError)


            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .unknownError)

            return false
        }
    }
    
    func startRecording() {
        // 检查是否有音频输入设备
        if !hasAvailableAudioInputDevices() {
            transcript = NSLocalizedString("error.audio.noDevice", comment: "No audio input device detected")
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .audioDeviceUnavailable)
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .audioDeviceUnavailable)
            return
        }
        
        isRecording = true
        recordingTime = 0.0 // 重置录音时间
        transcript = NSLocalizedString("recording.state.recording", comment: "Recording")
        audioData = Data() // 重置音频数据
        
        #if DEBUG
        // 开始内存监控（仅在调试模式）
        startMemoryMonitoring()
        #endif
        
        #if DEBUG
        // 开始内存监控（仅在调试模式）
        startMemoryMonitoring()
        #endif
        
        // 启动录音计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.recordingTime += 0.1
            }
        }
        
        // 发送录音开始通知
        NotificationCenter.default.post(name: Notification.Name("RecordingStarted"), object: nil)
        
        // 直接开始录音，权限检查应该在调用此方法之前完成
        // 先检查模型是否已下载
        if !self.isModelAlreadyDownloaded() {
            self.transcript = NSLocalizedString("model.status.download.required", comment: "Model not downloaded")
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
    }
    
    private var selectedLanguage: String = "zh" // 默认语言为中文
    private var isWhisperKitPreloading = false // 标记WhisperKit是否正在预加载
    
    func setLanguage(_ language: String) {
        selectedLanguage = language
        #if DEBUG
        #if DEBUG
        print("語言已設置為: \(selectedLanguage)")
        #endif
        #endif
        
        // 添加调试信息，查看 WhisperKit 是否支持语言设置
        if let whisperKit = whisperKit {
            // 尝试查看 whisperKit 是否有语言相关的属性或方法
            #if DEBUG
            #if DEBUG
            print("WhisperKit 實例: \(whisperKit)")
            #endif
            #endif
        }
    }
    
    // 预加载WhisperKit以减少首次录音延迟
    func preloadWhisperKit() async {
        // 避免重复预加载
        guard !isWhisperKitPreloading && whisperKit == nil else { return }
        
        isWhisperKitPreloading = true
        #if DEBUG
        #if DEBUG
        print("開始預加載WhisperKit...")
        #endif
        #endif
        
        do {
            // 根据选择的模型初始化WhisperKit
            var config = WhisperKitConfig(model: currentModel)
            let loadedWhisperKit = try await WhisperKit(config)
            
            await MainActor.run {
                self.whisperKit = loadedWhisperKit
                self.isWhisperKitPreloading = false
                #if DEBUG
                #if DEBUG
                print("WhisperKit 預加載完成")
                #endif
                #endif
            }
        } catch {
            #if DEBUG
            #if DEBUG
            print("WhisperKit 預加載失敗: \(error)")
            #endif
            #endif
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
            #if DEBUG
            #if DEBUG
            print("WhisperKit 初始化成功，使用模型: \(currentModel)")
            #endif
            #endif
            
            // 初始化完成后开始录音
            await MainActor.run {
                self.startAudioEngine()
            }
        } catch {
            #if DEBUG
            #if DEBUG
            print("WhisperKit 初始化失敗: \(error)")
            #endif
            #endif
            await MainActor.run {
                self.transcript = String(format: NSLocalizedString("model.status.load.failed", comment: "Model failed to load"), error.localizedDescription)
                self.isRecording = false
            }
            // 通过delegate报告错误
            self.delegate?.audioTranscriber(self, didEncounterError: .modelLoadFailed(reason: error.localizedDescription))
            // 通过delegate报告错误
            self.delegate?.audioTranscriber(self, didEncounterError: .modelLoadFailed(reason: error.localizedDescription))
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
            transcript = NSLocalizedString("error.audio.engineFailed", comment: "Audio engine initialization failed")
            isRecording = false
            return
        }
        
        // 获取输入节点
        let inputNode = audioEngine.inputNode
        let bus = 0
        
        // 使用输入节点的输出格式，避免格式不匹配
        let inputFormat = inputNode.outputFormat(forBus: bus)
        audioFormat = inputFormat // 保存音频格式
        
        #if DEBUG
        #if DEBUG
        print("音頻格式: \(inputFormat)")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("採樣率: \(inputFormat.sampleRate)")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("聲道數: \(inputFormat.channelCount)")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("位深度: \(inputFormat.settings[AVLinearPCMBitDepthKey] ?? "Unknown")")
        #endif
        #endif
        
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
                #if DEBUG
                #if DEBUG
                print("接收到音頻數據: \(buffer.frameLength) 幀, 音量: \(volume)")
                #endif
                #endif
                self.volumeLevel = volume // 更新音量级别
            }
            
            // 获取音频数据
            if let audioData = self.audioBufferToData(buffer, channelCount: channelCount, frameLength: frameLength) {
                DispatchQueue.main.async {
                    #if DEBUG
                    #if DEBUG
                    print("音頻數據大小: \(audioData.count) 字節")
                    #endif
                    #endif
                    self.audioData.append(audioData)
                }
            } else {
                DispatchQueue.main.async {
                    #if DEBUG
                    #if DEBUG
                    print("无法获取音频数据")
                    #endif
                    #endif
                }
            }
        }
        
        // 断开输入节点与主混音器的连接以避免音频反馈
        audioEngine.disconnectNodeInput(audioEngine.mainMixerNode)
        
        do {
            // 准备并启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            #if DEBUG
            #if DEBUG
            print("音频录制已开始")
            #endif
            #endif
        } catch {
            #if DEBUG
            #if DEBUG
            print("无法启动音频引擎: \(error)")
            #endif
            #endif
            isRecording = false
            transcript = String(format: NSLocalizedString("error.recording.startFailed", comment: "Recording start failed"), error.localizedDescription)
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .audioEngineFailed(reason: error.localizedDescription))
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .audioEngineFailed(reason: error.localizedDescription))
        }
    }
    
    // 将AVAudioPCMBuffer转换为Data
    private func audioBufferToData(_ buffer: AVAudioPCMBuffer, channelCount: Int, frameLength: Int) -> Data? {
        guard let channelData = buffer.floatChannelData else { 
            #if DEBUG
            #if DEBUG
            print("无法获取channelData")
            #endif
            #endif
            return nil 
        }
        
        // 检查数据有效性
        if frameLength == 0 {
            #if DEBUG
            #if DEBUG
            print("帧长度为0")
            #endif
            #endif
            return nil
        }
        
        // 打印缓冲区信息
        #if DEBUG
        #if DEBUG
        print("缓冲区信息: 帧长度=\(frameLength), 通道数=\(channelCount)")
        #endif
        #endif
        
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
        // 使用defer确保资源清理
        defer {
            #if DEBUG
            print("✅ stopRecording cleanup completed")
            #endif
        }

        // 使用defer确保资源清理
        defer {
            #if DEBUG
            print("✅ stopRecording cleanup completed")
            #endif
        }

        isRecording = false
        recordingTime = 0.0 // 重置录音时间

        #if DEBUG
        // 停止内存监控
        stopMemoryMonitoring()
        #endif

        // 1. 停止并清理录音计时器

        #if DEBUG
        // 停止内存监控
        stopMemoryMonitoring()
        #endif

        // 1. 停止并清理录音计时器
        recordingTimer?.invalidate()
        recordingTimer = nil

        // 2. 发送录音停止通知

        // 2. 发送录音停止通知
        NotificationCenter.default.post(name: Notification.Name("RecordingStopped"), object: nil)

        // 3. 停止音频引擎并清理资源
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }

            // 移除所有tap
            audioEngine.inputNode.removeTap(onBus: 0)

            #if DEBUG
            print("✅ Audio engine stopped and tap removed")
            #endif
        }

        // 4. 立即释放音频引擎

        // 3. 停止音频引擎并清理资源
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }

            // 移除所有tap
            audioEngine.inputNode.removeTap(onBus: 0)

            #if DEBUG
            print("✅ Audio engine stopped and tap removed")
            #endif
        }

        // 4. 立即释放音频引擎
        self.audioEngine = nil

        #if DEBUG

        #if DEBUG
        print("音頻錄製已停止")
        print("總音頻數據大小: \(audioData.count) 字節")
        #endif

        #endif

        transcript = NSLocalizedString("recording.state.processing", comment: "Processing recording")

        // 5. 检查音频数据并处理
        guard !audioData.isEmpty else {

        // 5. 检查音频数据并处理
        guard !audioData.isEmpty else {
            transcript = NSLocalizedString("error.transcription.emptyResult", comment: "No audio data recorded")
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .transcriptionEmptyResult)
            return
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .transcriptionEmptyResult)
            return
        }

        // 6. 处理音频数据
        processAudio()

        // 6. 处理音频数据
        processAudio()
    }
    
    private func processAudio() {
        guard !audioData.isEmpty else {
            transcript = NSLocalizedString("error.transcription.emptyResult", comment: "No audio data recorded")
            return
        }


        // 将音频数据保存到临时文件
        Task {
            var tempURL: URL?

            // 使用defer确保临时文件被清理
            defer {
                if let url = tempURL,
                   FileManager.default.fileExists(atPath: url.path) {
                    do {
                        try FileManager.default.removeItem(at: url)
                        #if DEBUG
                        print("✅ Cleaned up temp file: \(url.path)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("❌ Failed to clean up temp file: \(error)")
                        #endif
                    }
                }
            }

            do {
                // 使用新的安全临时文件创建方法
                tempURL = try createSecureTempFile()
                guard let tempFileURL = tempURL else {
                    throw NSError(domain: "AudioTranscriber", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp file"])
                }

                #if DEBUG
                print("音频文件路径: \(tempFileURL.path)")
                #endif

                try saveAudioDataToWAV(audioData, format: audioFormat, url: tempFileURL)

            var tempURL: URL?

            // 使用defer确保临时文件被清理
            defer {
                if let url = tempURL,
                   FileManager.default.fileExists(atPath: url.path) {
                    do {
                        try FileManager.default.removeItem(at: url)
                        #if DEBUG
                        print("✅ Cleaned up temp file: \(url.path)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("❌ Failed to clean up temp file: \(error)")
                        #endif
                    }
                }
            }

            do {
                // 使用新的安全临时文件创建方法
                tempURL = try createSecureTempFile()
                guard let tempFileURL = tempURL else {
                    throw NSError(domain: "AudioTranscriber", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp file"])
                }

                #if DEBUG
                print("音频文件路径: \(tempFileURL.path)")
                #endif

                try saveAudioDataToWAV(audioData, format: audioFormat, url: tempFileURL)

                // 检查保存的文件大小
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempFileURL.path)
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempFileURL.path)
                if let fileSize = fileAttributes[.size] as? NSNumber {
                    #if DEBUG
                    #if DEBUG
                    print("保存的文件大小: \(fileSize) 字节")
                    #endif
                    #endif
                }


                // 检查文件是否存在且不为空
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    let fileData = try Data(contentsOf: tempFileURL)
                    #if DEBUG
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    let fileData = try Data(contentsOf: tempFileURL)
                    #if DEBUG
                    print("实际文件大小: \(fileData.count) 字节")
                    #endif

                    #endif

                    // 验证WAV文件头
                    if fileData.count >= 44 {
                        let header = fileData.subdata(in: 0..<44)
                        #if DEBUG
                        #if DEBUG
                        print("WAV文件头: \(header.map { String(format: "%02x", $0) }.joined(separator: " "))")
                        #endif
                        #endif
                    }
                }


                // 使用WhisperKit进行转录
                await transcribeAudio(audioFilePath: tempFileURL.path)
                await transcribeAudio(audioFilePath: tempFileURL.path)
            } catch {
                #if DEBUG
                #if DEBUG
                print("音频处理失败: \(error)")
                #endif
                #endif
                await MainActor.run {
                    self.transcript = String(format: NSLocalizedString("error.audio.processingFailed", comment: "Audio processing failed"), error.localizedDescription)
                }
                // 通过delegate报告错误
                self.delegate?.audioTranscriber(self, didEncounterError: .audioProcessingFailed(reason: error.localizedDescription))
                // 通过delegate报告错误
                self.delegate?.audioTranscriber(self, didEncounterError: .audioProcessingFailed(reason: error.localizedDescription))
            }
        }
    }
    
    private func saveAudioDataToWAV(_ data: Data, format: AVAudioFormat?, url: URL) throws {
        // 使用输入的音频格式信息，如果不可用则使用默认值
        let sampleRate = format?.sampleRate ?? 44100  // 使用实际的采样率
        let channels = 1  // 强制使用单声道以确保兼容性
        let bitDepth = 16 // 强制使用16位深度以兼容Whisper
        
        #if DEBUG
        #if DEBUG
        print("保存音频数据到WAV文件:")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("  数据大小: \(data.count) 字节")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("  采样率: \(sampleRate)")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("  声道数: \(channels)")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("  位深度: \(bitDepth)")
        #endif
        #endif
        
        // 将浮点数据转换为16位PCM数据
        let convertedData = convertFloatToPCM16(data)
        #if DEBUG
        #if DEBUG
        print("转换后数据大小: \(convertedData.count) 字节")
        #endif
        #endif
        
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
        #if DEBUG
        #if DEBUG
        print("音频文件已保存到: \(url.path)")
        #endif
        #if DEBUG
        #endif
        #if DEBUG
        print("文件总大小: \(fileData.count) 字节")
        #endif
        #endif
        
        // 验证文件是否正确创建
        if FileManager.default.fileExists(atPath: url.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            #if DEBUG
            #if DEBUG
            print("验证文件大小: \(attrs[.size] ?? "Unknown") 字节")
            #endif
            #endif
        }
    }
    
    // 将浮点数据转换为16位PCM数据
    private func convertFloatToPCM16(_ floatData: Data) -> Data {
        // 如果数据为空，返回空数据
        guard !floatData.isEmpty else {
            #if DEBUG
            #if DEBUG
            print("输入数据为空")
            #endif
            #endif
            return Data()
        }
        
        // 计算浮点数的数量
        let floatCount = floatData.count / MemoryLayout<Float>.size
        
        // 检查数据大小是否正确
        if floatData.count % MemoryLayout<Float>.size != 0 {
            #if DEBUG
            #if DEBUG
            print("警告: 数据大小不是Float大小的整数倍")
            #endif
            #endif
        }
        
        // 创建一个新的Data对象来存储转换后的16位数据
        var int16Data = Data(capacity: floatCount * MemoryLayout<Int16>.size)
        
        // 逐个处理每个浮点数
        for i in 0..<floatCount {
            // 计算当前浮点数在数据中的位置
            let offset = i * MemoryLayout<Float>.size
            
            // 确保不会越界
            if offset + MemoryLayout<Float>.size > floatData.count {
                #if DEBUG
                #if DEBUG
                print("警告: 数据越界 at index \(i)")
                #endif
                #endif
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
        
        #if DEBUG
        #if DEBUG
        print("转换完成: \(floatCount) 个浮点数 -> \(int16Data.count) 字节")
        #endif
        #endif
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
            #if DEBUG
            #if DEBUG
            print("WhisperKit 未初始化")
            #endif
            #endif
            await MainActor.run {
                self.transcript = NSLocalizedString("model.status.load.failed", comment: "Model failed to load")
            }
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .modelLoadFailed(reason: "WhisperKit not initialized"))
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .modelLoadFailed(reason: "WhisperKit not initialized"))
            return
        }
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: audioFilePath) {
            #if DEBUG
            #if DEBUG
            print("音频文件不存在: \(audioFilePath)")
            #endif
            #endif
            await MainActor.run {
                self.transcript = NSLocalizedString("error.file.notFound", comment: "Audio file not found")
            }
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .fileNotFound(path: audioFilePath))
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .fileNotFound(path: audioFilePath))
            return
        }
        
        // 检查文件大小
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioFilePath)
            if let fileSize = fileAttributes[.size] as? NSNumber {
                #if DEBUG
                #if DEBUG
                print("轉錄文件大小: \(fileSize) 字節")
                #endif
                #endif
                if fileSize.intValue == 0 {
                    await MainActor.run {
                        self.transcript = NSLocalizedString("error.file.empty", comment: "Audio file is empty")
                    }
                    // 通过delegate报告错误
                    delegate?.audioTranscriber(self, didEncounterError: .fileEmpty(path: audioFilePath))
                    // 通过delegate报告错误
                    delegate?.audioTranscriber(self, didEncounterError: .fileEmpty(path: audioFilePath))
                    return
                }
            }
        } catch {
            #if DEBUG
            #if DEBUG
            print("無法獲取文件信息: \(error)")
            #endif
            #endif
        }
        
        do {
            #if DEBUG
            #if DEBUG
            print("開始轉錄音頻文件: \(audioFilePath)")
            #endif
            #endif
            
            // 使用 DecodingOptions 配置语言
            let decodingOptions = DecodingOptions(
                language: selectedLanguage, // 使用设置的语言代码
                temperature: 0.0,
                sampleLength: 224
            )
            
            #if DEBUG
            #if DEBUG
            print("使用語言: \(selectedLanguage)")
            #endif
            #endif
            
            // 调用 transcribe 方法并传入解码选项
            let result = try await whisperKit.transcribe(
                audioPath: audioFilePath,
                decodeOptions: decodingOptions
            )
            
            #if DEBUG
            #if DEBUG
            print("轉錄完成")
            #endif
            #endif
            
            await MainActor.run {
                // 处理转录结果
                var extractedText = NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result")
                
                if let results = result as? [TranscriptionResult] {
                    // 如果是TranscriptionResult数组
                    if let firstResult = results.first {
                        extractedText = firstResult.text ?? NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result")
                    }
                } else if let textResults = result as? [String] {
                    // 如果是字符串数组
                    if let firstText = textResults.first {
                        extractedText = firstText.isEmpty ? NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result") : firstText
                    }
                } else if let singleText = result as? String {
                    // 如果是单个字符串
                    extractedText = singleText.isEmpty ? NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result") : singleText
                } else {
                    // 尝试获取text属性
                    if let text = (result as? NSObject)?.value(forKey: "text") as? String {
                        extractedText = text.isEmpty ? NSLocalizedString("error.transcription.emptyResult", comment: "Empty transcription result") : text
                    }
                }
                
                self.transcript = extractedText
                #if DEBUG
                #if DEBUG
                print("轉錄結果: \(extractedText)")
                #endif
                #endif
            }
        } catch {
            #if DEBUG
            #if DEBUG
            print("转录失败: \(error)")
            #endif
            #endif
            await MainActor.run {
                self.transcript = String(format: NSLocalizedString("error.transcription.failed", comment: "Transcription failed"), error.localizedDescription)
            }
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .transcriptionFailed(reason: error.localizedDescription))
            // 通过delegate报告错误
            delegate?.audioTranscriber(self, didEncounterError: .transcriptionFailed(reason: error.localizedDescription))
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
            return device.name != NSLocalizedString("status.device.unknown", comment: "Unknown device") && !device.name.isEmpty
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
                if deviceName != NSLocalizedString("status.device.unknown", comment: "Unknown device") && !deviceName.isEmpty {
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
        if status != noErr { return NSLocalizedString("status.device.unknown", comment: "Unknown device") }
        
        var deviceNameCFString: CFString?
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &deviceNameCFString)
        if status == noErr, let name = deviceNameCFString {
            deviceName = name as String
        } else {
            deviceName = NSLocalizedString("status.device.unknown", comment: "Unknown device")
        }
        
        return deviceName
    }
    
    // 设置选择的音频设备
    func setSelectedDevice(index: Int) {
        guard index < audioDevices.count else { 
            #if DEBUG
            #if DEBUG
            print("无效的设备索引: \(index), 设备数量: \(audioDevices.count)")
            #endif
            #endif
            return 
        }
        selectedDeviceIndex = index
        selectedDeviceID = audioDevices[index].id
        #if DEBUG
        #if DEBUG
        print("已选择设备索引: \(index), 设备ID: \(audioDevices[index].id), 设备名称: \(audioDevices[index].name)")
        #endif
        #endif
        UserDefaults.standard.set(index, forKey: "SelectedDeviceIndex")
    }

    // MARK: - Memory Monitoring (Debug Only)

    #if DEBUG
    func startMemoryMonitoring() {
        // 获取初始内存 - 在主线程同步执行以避免actor隔离问题
        var initialMemory: Double = 0.0
        let semaphore = DispatchSemaphore(value: 0)

        logMemoryUsage { memory in
            initialMemory = memory
            semaphore.signal()
        }
        semaphore.wait()

        // 在主线程设置基线
        self.baselineMemory = initialMemory

        // 每 5 秒监控一次 - 使用RunLoop在主线程
        DispatchQueue.main.async { [weak self] in
            self?.memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                guard let self = self else { return }
                self.logMemoryUsage { currentMemory in
                    // 直接在主线程打印，避免actor隔离
                    let delta = currentMemory - self.baselineMemory
                    print("📊 Memory: \(String(format: "%.2f", currentMemory)) MB (Δ: \(String(format: "%.2f", delta)) MB)")

                    // 警告如果增长超过 100MB
                    if delta > 100.0 {
                        print("⚠️ WARNING: Memory grew by \(String(format: "%.2f", delta)) MB!")
                    }
                }
            }
        }
    }

    func stopMemoryMonitoring() {
        // 在主线程执行定时器操作
        DispatchQueue.main.async { [weak self] in
            self?.memoryMonitorTimer?.invalidate()
            self?.memoryMonitorTimer = nil
            print("📊 Memory monitoring stopped")
        }
    }

    private func logMemoryUsage(completion: @escaping (Double) -> Void) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryMB = Double(taskInfo.phys_footprint) / 1024.0 / 1024.0
            completion(memoryMB)
        } else {
            completion(0.0)
        }
    }
    #endif

    // MARK: - Temporary File Management

    private func createSecureTempFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vocaltext")

        // 创建目录
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // 创建唯一文件名
        let fileName = "recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        self.audioFileURL = fileURL

        #if DEBUG
        print("✅ Created temp file: \(fileURL.path)")
        #endif

        return fileURL
    }





    // MARK: - Memory Monitoring (Debug Only)

    #if DEBUG
    func startMemoryMonitoring() {
        // 获取初始内存 - 在主线程同步执行以避免actor隔离问题
        var initialMemory: Double = 0.0
        let semaphore = DispatchSemaphore(value: 0)

        logMemoryUsage { memory in
            initialMemory = memory
            semaphore.signal()
        }
        semaphore.wait()

        // 在主线程设置基线
        self.baselineMemory = initialMemory

        // 每 5 秒监控一次 - 使用RunLoop在主线程
        DispatchQueue.main.async { [weak self] in
            self?.memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                guard let self = self else { return }
                self.logMemoryUsage { currentMemory in
                    // 直接在主线程打印，避免actor隔离
                    let delta = currentMemory - self.baselineMemory
                    print("📊 Memory: \(String(format: "%.2f", currentMemory)) MB (Δ: \(String(format: "%.2f", delta)) MB)")

                    // 警告如果增长超过 100MB
                    if delta > 100.0 {
                        print("⚠️ WARNING: Memory grew by \(String(format: "%.2f", delta)) MB!")
                    }
                }
            }
        }
    }

    func stopMemoryMonitoring() {
        // 在主线程执行定时器操作
        DispatchQueue.main.async { [weak self] in
            self?.memoryMonitorTimer?.invalidate()
            self?.memoryMonitorTimer = nil
            print("📊 Memory monitoring stopped")
        }
    }

    private func logMemoryUsage(completion: @escaping (Double) -> Void) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryMB = Double(taskInfo.phys_footprint) / 1024.0 / 1024.0
            completion(memoryMB)
        } else {
            completion(0.0)
        }
    }
    #endif

    // MARK: - Temporary File Management

    private func createSecureTempFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vocaltext")

        // 创建目录
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // 创建唯一文件名
        let fileName = "recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        self.audioFileURL = fileURL

        #if DEBUG
        print("✅ Created temp file: \(fileURL.path)")
        #endif

        return fileURL
    }




    // 移除监听器
    deinit {
        #if DEBUG
        print("🔄 AudioTranscriber deinit called")
        #endif

        // 1. 停止内存监控（调试模式，内联实现）
        #if DEBUG
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        print("📊 Memory monitoring stopped")
        #endif

        // 2. 停止所有定时器
        #if DEBUG
        print("🔄 AudioTranscriber deinit called")
        #endif

        // 1. 停止内存监控（调试模式，内联实现）
        #if DEBUG
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        print("📊 Memory monitoring stopped")
        #endif

        // 2. 停止所有定时器
        deviceMonitoringTimer?.invalidate()
        deviceMonitoringTimer = nil


        recordingTimer?.invalidate()
        recordingTimer = nil

        // 3. 清理临时文件（内联实现，避免actor隔离问题）
        if let url = audioFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
                #if DEBUG
                print("✅ Cleaned up temp file: \(url.path)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to clean up temp file: \(error)")
                #endif
            }
        }

        // 4. 清理整个临时目录（内联实现）
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("vocaltext")
        do {
            if FileManager.default.fileExists(atPath: tempDir.path) {
                try FileManager.default.removeItem(at: tempDir)
                #if DEBUG
                print("✅ Cleaned up entire temp directory: \(tempDir.path)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to clean up temp directory: \(error)")
            #endif
        }

        // 5. 清理音频数据
        audioData.removeAll()
        audioData = Data()

        // 6. 释放 WhisperKit
        whisperKit = nil

        // 7. 停止并清理音频引擎
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        // 8. 清理音频写入器
        audioWriter = nil

        #if DEBUG
        print("✅ AudioTranscriber resources cleaned up")
        #endif

        // 3. 清理临时文件（内联实现，避免actor隔离问题）
        if let url = audioFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
                #if DEBUG
                print("✅ Cleaned up temp file: \(url.path)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to clean up temp file: \(error)")
                #endif
            }
        }

        // 4. 清理整个临时目录（内联实现）
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("vocaltext")
        do {
            if FileManager.default.fileExists(atPath: tempDir.path) {
                try FileManager.default.removeItem(at: tempDir)
                #if DEBUG
                print("✅ Cleaned up entire temp directory: \(tempDir.path)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to clean up temp directory: \(error)")
            #endif
        }

        // 5. 清理音频数据
        audioData.removeAll()
        audioData = Data()

        // 6. 释放 WhisperKit
        whisperKit = nil

        // 7. 停止并清理音频引擎
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        // 8. 清理音频写入器
        audioWriter = nil

        #if DEBUG
        print("✅ AudioTranscriber resources cleaned up")
        #endif
    }
}
