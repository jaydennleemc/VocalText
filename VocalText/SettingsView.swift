//
//  SettingsView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioTranscriber: AudioTranscriber
    @Binding var isPresented: Bool
    @State private var selectedModel = "tiny"
    @State private var selectedDeviceIndex = 0
    @State private var selectedLanguage = "zh"  // 默认选择中文
    
    let models = ["tiny", "base", "small", "medium", "large-v3"]
    let languages = [
        ("zh", "中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español")
    ]
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        
        // 从 UserDefaults 加载保存的设置
        if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
            self._selectedModel = State(initialValue: savedModel)
        }
        
        // 从 UserDefaults 加载保存的设备索引
        self._selectedDeviceIndex = State(initialValue: UserDefaults.standard.integer(forKey: "SelectedDeviceIndex"))
        
        // 从 UserDefaults 加载保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            self._selectedLanguage = State(initialValue: savedLanguage)
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)
            
            Divider()
            
            VStack {
                // 将内容包装在 ScrollView 中以支持滚动
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("模型选择")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Picker("", selection: $selectedModel) {
                                ForEach(models, id: \.self) { model in
                                    HStack {
                                        Text(model)
                                        if audioTranscriber.isModelAlreadyDownloaded(model: model) {
                                            Text("(已下载)")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        } else {
                                            Text("(需要下载)")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                        }
                                    }
                                    .tag(model)
                                }
                            }
                            .pickerStyle(RadioGroupPickerStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("音频输入设备")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Picker("", selection: $selectedDeviceIndex) {
                                ForEach(0..<audioTranscriber.audioDevices.count, id: \.self) { index in
                                    Text(audioTranscriber.audioDevices[index].name).tag(index)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("语言设置")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Picker("", selection: $selectedLanguage) {
                                ForEach(languages, id: \.0) { code, name in
                                    Text(name).tag(code)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                // 保存按钮放在底部
                Button("保存") {
                    // 保存设置到 UserDefaults
                    UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
                    UserDefaults.standard.set(selectedDeviceIndex, forKey: "SelectedDeviceIndex")
                    UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
                    
                    // 通知AudioTranscriber设置选择的设备和语言
                    audioTranscriber.setSelectedDevice(index: selectedDeviceIndex)
                    audioTranscriber.setLanguage(selectedLanguage)
                    
                    // 通知主视图模型已更改
                    NotificationCenter.default.post(name: Notification.Name("ModelChanged"), object: nil)
                    
                    print("设置已保存 - 模型: \(selectedModel), 设备索引: \(selectedDeviceIndex), 语言: \(selectedLanguage)")
                    
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
            }
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AudioTranscriber())
}
