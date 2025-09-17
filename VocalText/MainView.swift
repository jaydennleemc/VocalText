//
//  MainView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import AppKit
import AVFoundation

struct MainView: View {
    @StateObject private var audioTranscriber = AudioTranscriber()
    @State private var isRecording = false
    @State private var showSettingsView = false
    @State private var selectedModel = "Tiny"
    @State private var hasMicrophonePermission = false
    @State private var modelDownloaded = false
    @State private var isRealTimeMode = false // 实时转录模式
    
    var body: some View {
        VStack {
            HStack {
                // 实时转录切换按钮
                Button(action: {
                    isRealTimeMode.toggle()
                    audioTranscriber.enableRealTimeTranscription(isRealTimeMode)
                }) {
                    HStack {
                        Image(systemName: isRealTimeMode ? "waveform.circle.fill" : "waveform.circle")
                        Text(isRealTimeMode ? "实时转录" : "实时转录")
                    }
                    .foregroundColor(isRealTimeMode ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(4)
                
                Spacer()
                
                Button(action: {
                    // 显示设置界面
                    showSettingsView = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(4)
                .sheet(isPresented: $showSettingsView) {
                    SettingsView(
                        isPresented: $showSettingsView,
                        audioDevices: audioTranscriber.audioDevices,
                        onDeviceSelected: { index in
                            audioTranscriber.setSelectedDevice(index: index)
                        }
                    )
                }
            }
            
            Spacer()
            
            // 显示下载进度或转录文本
            if audioTranscriber.isDownloading {
                VStack {
                    Text(audioTranscriber.downloadStatus)
                    ProgressView(value: audioTranscriber.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                }
            } else {
                Text(audioTranscriber.transcript)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            } else {
                // 录音按钮
                HStack {
                    Button(action: {
                        isRecording.toggle()
                        if isRecording {
                            // 设置模型并开始录音
                            audioTranscriber.setModel(selectedModel)
                            audioTranscriber.startRecording()
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
            }
        }
        .frame(width: 400, height: 300) // 增大窗口尺寸
        .onAppear {
            checkMicrophonePermission()
            checkModelDownloaded()
            audioTranscriber.getAvailableAudioDevices()
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
        // 检查模型是否已下载
        modelDownloaded = audioTranscriber.isModelDownloaded
    }
    
    // 下载默认模型
    private func downloadDefaultModel() {
        audioTranscriber.setModel(selectedModel)
        Task {
            let success = await audioTranscriber.checkAndDownloadModelIfNeeded()
            DispatchQueue.main.async {
                modelDownloaded = success
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
