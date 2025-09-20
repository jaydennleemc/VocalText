//
//  MainView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import AppKit
import AVFoundation
import UserNotifications

// 类似iOS语音备忘录的波形视图
struct VoiceMemoWaveformView: View {
    @Binding var volumeLevel: Double
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 50)
    @State private var lastVolumeUpdate: Date = Date()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.7)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: max(2, bars[index] * 60))
                    .animation(.easeOut(duration: 0.15), value: bars[index])
            }
        }
        .frame(height: 60)
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            updateBars()
        }
        // 监听音量变化并立即更新
        .onChange(of: volumeLevel) { _ in
            updateBarsWithVolume()
        }
    }
    
    private func updateBars() {
        // 创建类似iOS语音备忘录的波形效果
        // 移除第一个条形，创建从右到左的滚动效果
        bars.removeFirst()
        
        // 根据音量添加新的条形高度
        // 使用当前音量级别作为主要因素
        let newBarHeight = CGFloat(volumeLevel)
        bars.append(newBarHeight)
        
        // 应用平滑效果，使相邻条形高度变化更自然
        if bars.count >= 3 {
            for i in 1..<bars.count-1 {
                bars[i] = (bars[i-1] + bars[i] + bars[i+1]) / 3
            }
        }
    }
    
    private func updateBarsWithVolume() {
        // 直接响应音量变化更新最后一个条形
        if !bars.isEmpty {
            // 使用当前音量级别作为主要因素，添加一些随机性使波形更自然
            let randomFactor = Double.random(in: 0.8...1.2)
            let adjustedVolume = volumeLevel * randomFactor
            let newBarHeight = CGFloat(min(1.0, adjustedVolume))
            bars[bars.count - 1] = newBarHeight
            
            // 应用局部平滑效果
            let index = bars.count - 1
            if index >= 2 {
                for i in (index - 2)..<index {
                    if i > 0 && i < bars.count - 1 {
                        bars[i] = (bars[i-1] + bars[i] + bars[i+1]) / 3
                    }
                }
            }
        }
    }
}

struct WaveAnimation: View {
    @State private var waveOffset = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4, height: 20 + CGFloat(sin(waveOffset + Double(i)) * 10))
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                        value: waveOffset
                    )
            }
        }
        .onAppear {
            waveOffset = .pi
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainView: View {
    @StateObject private var audioTranscriber = AudioTranscriber()
    @State private var isRecording = false
    @State private var showSettingsView = false
    @State private var showTutorialView = false
    @State private var selectedModel = "Tiny" {
        didSet {
            // 保存選擇的模型到 UserDefaults
            UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        }
    }
    @State private var hasMicrophonePermission = false
    @State private var isCheckingMicrophonePermission = true // 新增状态，用于跟踪是否正在检查麦克风权限
    @State private var hasRequestedMicrophonePermission = false // 新增状态，用于跟踪是否已经请求过麦克风权限
    @State private var modelDownloaded = false
    @State private var isModelDownloading = false
    @State private var hasCheckedModelStatus = false
    @State private var hasAudioInputDevices = true // 新增状态，用于跟踪是否有音频输入设备
    @State private var isDownloadingModel = false // 新增状态，用于跟踪是否正在下载模型
    
    var body: some View {
        ZStack {
            // 主页面内容
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // 显示设置界面
                        showSettingsView = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .disabled(audioTranscriber.isRecording || audioTranscriber.isTranscribing || showTutorialView) // 录音、转录或教程期间禁用设置按钮
                }
                .opacity(showSettingsView || showTutorialView ? 0 : 1) // 当设置页面或教程显示时隐藏设置按钮
                
                Spacer()
                
                // 显示下载进度、转录文本或处理中状态
                if !hasCheckedModelStatus {
                    // 还未检查模型状态，显示加载状态
                    VStack {
                        Text("正在檢查模型狀態...")
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                    .opacity(showSettingsView || showTutorialView ? 0 : 1)
                } else if isCheckingMicrophonePermission {
                    // 正在检查麦克风权限，显示加载状态
                    VStack {
                        Text("正在請求麥克風權限...")
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                    .opacity(showSettingsView || showTutorialView ? 0 : 1)
                } else if audioTranscriber.isDownloading || isModelDownloading {
                    VStack {
                        Text(audioTranscriber.downloadStatus)
                        ProgressView(value: audioTranscriber.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                    }
                    .opacity(showSettingsView || showTutorialView ? 0 : 1) // 当设置页面或教程显示时隐藏内容
                } else if audioTranscriber.isTranscribing {
                    // 显示转录处理中状态
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.0)
                        Spacer()
                    }
                    .opacity(showSettingsView || showTutorialView ? 0 : 1) // 当设置页面或教程显示时隐藏内容
                } else {
                    Group {
                        if isRecording {
                            // 使用类似iOS语音备忘录的波形视图
                            VoiceMemoWaveformView(volumeLevel: $audioTranscriber.volumeLevel)
                        } else {
                            // 根据权限状态显示不同的文本
                            if !hasMicrophonePermission && hasRequestedMicrophonePermission {
                                // 用户拒绝了麦克风权限
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("需要麥克風權限才能錄音")
                                        .font(.headline)
                                    Text("此應用需要訪問您的麥克風以錄製音頻並轉錄為文字。請點擊下方按鈕授予權限。")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            } else {
                                // 正常显示转录文本
                                Group {
                                    if audioTranscriber.transcript == "點擊開始錄音..." && !hasAudioInputDevices {
                                        // 没有音频输入设备时显示麦克风加斜线图标
                                        VStack {
                                            Image(systemName: "mic.slash.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("未檢測到音頻設備")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 5)
                                        }
                                    } else {
                                        Text(audioTranscriber.transcript)
                                            .onTapGesture {
                                                copyToClipboard(audioTranscriber.transcript)
                                            }
                                            .contextMenu {
                                                Button("复制到剪贴板") {
                                                    copyToClipboard(audioTranscriber.transcript)
                                                }
                                            }
                                    }
                                }
                                .opacity(showTutorialView ? 0 : 1) // 当教程显示时隐藏内容
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .opacity(showTutorialView ? 0 : 1) // 当教程显示时隐藏内容
                    .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏内容
                }
                
                Spacer()
                
                Spacer()
                
                // 根据状态显示不同的按钮
                if !hasCheckedModelStatus || isCheckingMicrophonePermission {
                    // 还未检查模型状态或正在检查麦克风权限，不显示任何按钮
                    EmptyView()
                    .opacity(showTutorialView ? 0 : 1) // 当教程显示时隐藏内容
                } else if !hasMicrophonePermission {
                    // 请求麦克风权限按钮
                    Button(action: {
                        requestMicrophonePermission()
                    }) {
                        Text("獲取麥克風權限")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                    .opacity(showSettingsView || showTutorialView ? 0 : 1) // 当设置页面或教程显示时隐藏按钮
                } else if !hasAudioInputDevices {
                    // 没有音频输入设备，显示提示信息
                    VStack(spacing: 10) {
                        Text("未檢測到音頻輸入設備")
                            .font(.headline)
                        Text("請連接麥克風或其他音頻輸入設備")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .opacity(showSettingsView || showTutorialView ? 0 : 1) // 当设置页面或教程显示时隐藏内容
                } else {
                    // 录音按钮
                    HStack {
                        Button(action: {
                            isRecording.toggle()
                            if isRecording {
                                // 設置模型並開始錄音
                                audioTranscriber.setModel(selectedModel)
                                // 设置语言
                                if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                                    audioTranscriber.setLanguage(savedLanguage)
                                }
                                // 直接开始录音，模型检查在AudioTranscriber内部处理
                                audioTranscriber.startRecording()
                            } else {
                                audioTranscriber.stopRecording()
                            }
                        }) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isRecording ? .red : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                        .disabled(isModelDownloading || showTutorialView) // 下载期间或教程显示时禁用录音按钮
                    }
                    .opacity(showSettingsView || showTutorialView ? 0 : 1) // 当设置页面或教程显示时隐藏按钮
                }
            }
            .frame(width: 400, height: 300) // 增大窗口尺寸
            
            // 设置页面
            if showSettingsView {
                SettingsView(
                    isPresented: $showSettingsView
                )
                .environmentObject(audioTranscriber)
                .onDisappear {
                    // 當設置視圖關閉時，重新檢查模型狀態
                    checkModelStatus()
                }
            }
            
            // 教程视图 - 居中显示
            if showTutorialView {
                TutorialView(
                    isPresented: $showTutorialView,
                    onTutorialCompleted: {
                        // 教程完成时检查麦克风权限
                        checkMicrophonePermission()
                    }
                )
                .transition(.move(edge: .leading))
                .frame(width: 400, height: 300)
            }
        }
        .frame(width: 400, height: 300) // 增大窗口尺寸
        .onAppear {
            // 检查是否需要显示教程
            let hasCompletedTutorial = UserDefaults.standard.bool(forKey: "HasCompletedTutorial")
            if !hasCompletedTutorial {
                // 延迟显示教程，确保UI已完全加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showTutorialView = true
                }
            }
            
            // 每次启动时检查麦克风权限状态
            checkMicrophonePermission()
            audioTranscriber.getAvailableAudioDevices()
            
            // 检查是否有音頻輸入設備
            hasAudioInputDevices = audioTranscriber.hasAvailableAudioInputDevices()
            
            // 註冊音頻設備變化通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("AudioDevicesChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // 重新檢查音頻輸入設備
                self.hasAudioInputDevices = self.audioTranscriber.hasAvailableAudioInputDevices()
            }
            
            // 從 UserDefaults 加載保存的設置
            if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
                selectedModel = savedModel
            }
            
            // 檢查模型是否已下載
            checkModelStatus()
            
            // 註冊模型更改通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ModelChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // 從 UserDefaults 重新加載保存的設置
                if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
                    selectedModel = savedModel
                }
                
                // 重新檢查模型是否已下載（但不自动下载）
                let isDownloaded = self.audioTranscriber.isModelAlreadyDownloaded(model: self.selectedModel.lowercased())
                self.modelDownloaded = isDownloaded
                self.hasCheckedModelStatus = true
                print("模型已更改，检查模型下载状态: \(isDownloaded) for model: \(self.selectedModel.lowercased())")
                
                if isDownloaded {
                    // 如果模型已下载，预加载WhisperKit
                    Task {
                        await self.audioTranscriber.preloadWhisperKit()
                    }
                }
            }
            
            // 註冊模型下載請求通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ModelDownloadRequested"),
                object: nil,
                queue: .main
            ) { notification in
                if let model = notification.object as? String {
                    // 开始下载模型
                    downloadModel(model: model)
                }
            }
            
            // 註冊模型下載開始通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ModelDownloadStarted"),
                object: nil,
                queue: .main
            ) { _ in
                // 激活应用并防止隐藏
                NSApp.activate(ignoringOtherApps: true)
                print("模型下载开始，应用已激活")
            }
            
            // 註冊模型下載完成通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ModelDownloadFinished"),
                object: nil,
                queue: .main
            ) { _ in
                // 下载完成后恢复正常行为
                print("模型下载完成")
            }
            
            // 延遲設置設備選擇，確保音頻設備已加載
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let savedDeviceIndex = UserDefaults.standard.integer(forKey: "SelectedDeviceIndex")
                if savedDeviceIndex < audioTranscriber.audioDevices.count {
                    audioTranscriber.setSelectedDevice(index: savedDeviceIndex)
                }
                
                // 加载保存的语言设置
                if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                    audioTranscriber.setLanguage(savedLanguage)
                }
            }
        }
    }
    
    // 检查麦克风权限
    private func checkMicrophonePermission() {
        // 设置正在检查权限的状态
        isCheckingMicrophonePermission = true
        
        // 请求权限以检查状态
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
                isCheckingMicrophonePermission = false // 检查完成后更新状态
                hasRequestedMicrophonePermission = true // 标记已经请求过权限
            }
        }
    }
    
    // 请求麦克风权限
    private func requestMicrophonePermission() {
        // 设置正在检查权限的状态
        isCheckingMicrophonePermission = true
        hasRequestedMicrophonePermission = true // 标记已经请求过权限
        
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
                isCheckingMicrophonePermission = false // 请求完成后更新状态
                
                if !granted {
                    // 显示系统设置提示
                    let alert = NSAlert()
                    alert.messageText = "需要麥克風權限"
                    alert.informativeText = "請在系統設置中允許此應用訪問麥克風。"
                    alert.addButton(withTitle: "打開設置")
                    alert.addButton(withTitle: "取消")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                    }
                }
            }
        }
    }
    
    // 检查模型状态
    private func checkModelStatus() {
        // 检查当前选择的模型是否已下载
        let isDownloaded = audioTranscriber.isModelAlreadyDownloaded(model: selectedModel.lowercased())
        modelDownloaded = isDownloaded
        hasCheckedModelStatus = true
        print("检查模型下载状态: \(isDownloaded) for model: \(selectedModel.lowercased())")
        
        // 如果模型未下载，自动开始下载
        if !isDownloaded {
            print("模型 \(selectedModel) 未下载，准备开始下载...")
            downloadModel(model: selectedModel)
        }
        
        // 如果模型已下载，预加载WhisperKit
        if isDownloaded {
            Task {
                await audioTranscriber.preloadWhisperKit()
            }
        }
    }
    
    // 检查模型是否已下载
    private func checkModelDownloaded() {
        // 检查当前选择的模型是否已下载
        let isDownloaded = audioTranscriber.isModelAlreadyDownloaded(model: selectedModel.lowercased())
        modelDownloaded = isDownloaded
        print("检查模型下载状态: \(isDownloaded) for model: \(selectedModel.lowercased())")
    }
    
    // 更新设备显示信息
    private func updateDeviceDisplay() {
        // 这个方法将在视图中自动更新设备显示
        // 因为我们使用了@Published属性
    }
    
    // 下载默认模型
    private func downloadDefaultModel() {
        audioTranscriber.setModel(selectedModel)
        // 设置语言
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            audioTranscriber.setLanguage(savedLanguage)
        }
        Task {
            let success = await audioTranscriber.checkAndDownloadModelIfNeeded()
            DispatchQueue.main.async {
                modelDownloaded = success
                if success {
                    // 发送通知更新UI
                    NotificationCenter.default.post(name: Notification.Name("ModelChanged"), object: nil)
                }
            }
        }
    }
    
    // 下载指定模型
    private func downloadModel(model: String) {
        // 防止重复下载
        if isDownloadingModel {
            print("模型 \(model) 正在下载中，跳过重复下载请求")
            return
        }
        
        // 设置要下载的模型
        audioTranscriber.setModel(model)
        
        // 设置语言
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            audioTranscriber.setLanguage(savedLanguage)
        }
        
        // 开始下载并显示进度
        isModelDownloading = true
        isDownloadingModel = true
        
        // 激活应用以防止在下载期间被隐藏
        NSApp.activate(ignoringOtherApps: true)
        
        Task {
            let success = await audioTranscriber.checkAndDownloadModelIfNeeded()
            DispatchQueue.main.async {
                isModelDownloading = false
                isDownloadingModel = false
                modelDownloaded = success
                if success {
                    // 下载成功后预加载WhisperKit
                    Task {
                        await audioTranscriber.preloadWhisperKit()
                    }
                    // 发送通知更新UI
                    NotificationCenter.default.post(name: Notification.Name("ModelChanged"), object: nil)
                }
            }
        }
    }
    
    // 复制文本到剪贴板
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                // 创建并发送通知
                let content = UNMutableNotificationContent()
                content.title = "已複製"
                content.body = "文本已複製到剪貼板"
                content.sound = .default
                
                let request = UNNotificationRequest(identifier: "CopyToClipboard", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("通知发送失败: \(error)")
                    }
                }
            } else if let error = error {
                print("通知权限被拒绝: \(error)")
            }
        }
    }
}

struct SettingsMenuView: View {
    @Binding var selectedModel: String
    @Environment(\.presentationMode) var presentationMode
    var audioTranscriber: AudioTranscriber
    
    let models = ["Tiny", "Base", "Small", "Medium"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(models, id: \.self) { model in
                Button(action: {
                    selectedModel = model
                    // 这里可以添加实际的模型切换逻辑
                    print("选择了模型: \(model)")
                }) {
                    HStack {
                        Text(model)
                        Spacer()
                        if model == selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if model != models.last {
                    Divider()
                }
            }
            
            Divider()
            
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Text("退出")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 150)
        .padding(.vertical, 8)
    }
}
