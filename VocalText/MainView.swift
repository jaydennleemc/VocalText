//
//  MainView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import AppKit
import AVFoundation

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
    @State private var selectedModel = "Tiny" {
        didSet {
            // 保存選擇的模型到 UserDefaults
            UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        }
    }
    @State private var hasMicrophonePermission = false
    @State private var modelDownloaded = false
    
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
                }
                .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏设置按钮
                
                Spacer()
                
                // 显示下载进度或转录文本
                if audioTranscriber.isDownloading {
                    VStack {
                        Text(audioTranscriber.downloadStatus)
                        ProgressView(value: audioTranscriber.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                    }
                    .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏内容
                } else {
                    Group {
                        if isRecording {
                            WaveAnimation()
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
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏内容
                }
                
                Spacer()
                
                // 根据状态显示不同的按钮
                if !hasMicrophonePermission {
                    // 请求麦克风权限按钮
                    Button(action: {
                        requestMicrophonePermission()
                    }) {
                        Text("获取麦克风权限")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                    .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏按钮
                } else if !modelDownloaded {
                    // 下载模型按钮
                    Button(action: {
                        downloadDefaultModel()
                    }) {
                        Text("下载默认模型")
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                    .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏按钮
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
                                // 再次檢查模型是否已下載
                                if !audioTranscriber.isModelAlreadyDownloaded(model: selectedModel.lowercased()) {
                                    // 如果模型未下載，先下載模型
                                    Task {
                                        let downloadSuccess = await audioTranscriber.checkAndDownloadModelIfNeeded()
                                        if downloadSuccess {
                                            DispatchQueue.main.async {
                                                modelDownloaded = true
                                                audioTranscriber.startRecording()
                                            }
                                        } else {
                                            DispatchQueue.main.async {
                                                self.isRecording = false
                                                self.modelDownloaded = false
                                                // 錯誤訊息會在 AudioTranscriber 中處理
                                            }
                                        }
                                    }
                                } else {
                                    // 确保modelDownloaded状态正确
                                    modelDownloaded = true
                                    audioTranscriber.startRecording()
                                }
                            } else {
                                audioTranscriber.stopRecording()
                            }
                        }) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.title)
                                Text(isRecording ? "停止录音" : "开始录音")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(isRecording ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                    }
                    .opacity(showSettingsView ? 0 : 1) // 当设置页面显示时隐藏按钮
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
                    // 當設置視圖關閉時，重新檢查模型下載狀態
                    checkModelDownloaded()
                }
            }
        }
        .frame(width: 400, height: 300) // 增大窗口尺寸
        .onAppear {
            checkMicrophonePermission()
            audioTranscriber.getAvailableAudioDevices()
            
            // 從 UserDefaults 加載保存的設置
            if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
                selectedModel = savedModel
            }
            
            // 檢查模型是否已下載
            checkModelDownloaded()
            
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
                
                // 重新檢查模型是否已下載
                checkModelDownloaded()
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
        // 请求权限以检查状态
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
            }
        }
    }
    
    // 请求麦克风权限
    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
                if !granted {
                    // 显示系统设置提示
                    let alert = NSAlert()
                    alert.messageText = "需要麦克风权限"
                    alert.informativeText = "请在系统设置中允许此应用访问麦克风。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "打开设置")
                    alert.addButton(withTitle: "取消")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                    }
                }
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
    
    // 复制文本到剪贴板
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 显示一个简短的通知，告知用户文本已复制
        let notification = NSUserNotification()
        notification.title = "已复制"
        notification.informativeText = "文本已复制到剪贴板"
        NSUserNotificationCenter.default.deliver(notification)
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
