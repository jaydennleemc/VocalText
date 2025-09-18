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
    
    let models = ["tiny", "base", "small", "medium", "large-v3"]
    var audioDevices: [AudioTranscriber.AudioDevice] = []
    var onDeviceSelected: ((Int) -> Void)? = nil
    
    init(isPresented: Binding<Bool>, audioDevices: [AudioTranscriber.AudioDevice] = [], onDeviceSelected: ((Int) -> Void)? = nil) {
        self._isPresented = isPresented
        self.audioDevices = audioDevices
        self.onDeviceSelected = onDeviceSelected
        
        // 從 UserDefaults 加載保存的設置
        if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
            self._selectedModel = State(initialValue: savedModel)
        }
        
        // 從 UserDefaults 加載保存的設備索引
        self._selectedDeviceIndex = State(initialValue: UserDefaults.standard.integer(forKey: "SelectedDeviceIndex"))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            .padding(.top, 10)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("模型选择")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Picker("选择模型", selection: $selectedModel) {
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
            .padding(.horizontal, 10)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("音频输入设备")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Picker("选择设备", selection: $selectedDeviceIndex) {
                    ForEach(0..<audioDevices.count, id: \.self) { index in
                        Text(audioDevices[index].name).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 300) // 设置设备选择器的宽度
                .onChange(of: selectedDeviceIndex) { newValue in
                    onDeviceSelected?(newValue)
                }
            }
            .padding(.horizontal, 10)
            
            Divider()
            
            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                
                Button("保存") {
                    // 保存设置到 UserDefaults
                    UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
                    UserDefaults.standard.set(selectedDeviceIndex, forKey: "SelectedDeviceIndex")
                    
                    // 通知主視圖模型已更改
                    NotificationCenter.default.post(name: Notification.Name("ModelChanged"), object: nil)
                    
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)
        }
        .padding()
        .frame(width: 450, height: 350) // 增大窗口尺寸
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}