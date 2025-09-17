//
//  SettingsView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

struct SettingsView: View {
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
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("模型选择")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Picker("选择模型", selection: $selectedModel) {
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
            }
            
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
            
            Divider()
            
            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存") {
                    // 保存设置
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450, height: 350) // 增大窗口尺寸
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}