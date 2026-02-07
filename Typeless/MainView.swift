//
//  MainView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import AppKit
import AVFoundation
import UserNotifications

// MARK: - Error Type System

enum ErrorType {
    case warning
    case error
    case info

    var color: Color {
        switch self {
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .warning: return .orange.opacity(0.1)
        case .error: return .red.opacity(0.1)
        case .info: return .blue.opacity(0.1)
        }
    }

    var borderColor: Color {
        switch self {
        case .warning: return .orange.opacity(0.3)
        case .error: return .red.opacity(0.3)
        case .info: return .blue.opacity(0.3)
        }
    }
}

// MARK: - TypelessError Enum

enum TypelessError: LocalizedError, Equatable {
    // 麦克风权限相关
    case microphonePermissionDenied
    case microphonePermissionRestricted

    // 网络相关
    case networkNotConnected
    case networkTimeout
    case networkServerNotFound
    case networkGeneric(underlying: Error)

    // 模型相关
    case modelDownloadFailed(reason: String)
    case modelLoadFailed(reason: String)
    case modelNotFound(model: String)

    // 录音相关
    case audioDeviceUnavailable
    case audioEngineFailed(reason: String)
    case audioRecordingFailed(reason: String)
    case audioProcessingFailed(reason: String)

    // 转录相关
    case transcriptionFailed(reason: String)
    case transcriptionEmptyResult
    case transcriptionInvalidFormat

    // 文件相关
    case fileNotFound(path: String)
    case fileEmpty(path: String)
    case fileWriteFailed(reason: String)

    // 通用错误
    case invalidState(description: String)
    case unknownError

    // MARK: - LocalizedError 协议实现

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("error.audio.permissionDenied", comment: "麦克风权限被拒绝")

        case .microphonePermissionRestricted:
            return NSLocalizedString("error.audio.permissionRestricted", comment: "麦克风权限受限")

        case .networkNotConnected:
            return NSLocalizedString("error.network.notConnected", comment: "无网络连接")

        case .networkTimeout:
            return NSLocalizedString("error.network.timeout", comment: "连接超时")

        case .networkServerNotFound:
            return NSLocalizedString("error.network.serverNotFound", comment: "找不到服务器")

        case .networkGeneric(let underlying):
            return String(format: NSLocalizedString("error.network.generic", comment: "网络错误"), underlying.localizedDescription)

        case .modelDownloadFailed(let reason):
            return String(format: NSLocalizedString("model.status.download.failed", comment: "模型下载失败"), reason)

        case .modelLoadFailed(let reason):
            return String(format: NSLocalizedString("model.status.load.failed", comment: "模型加载失败"), reason)

        case .modelNotFound(let model):
            return String(format: NSLocalizedString("error.model.notFound", comment: "模型未找到"), model)

        case .audioDeviceUnavailable:
            return NSLocalizedString("error.audio.noDevice", comment: "无音频设备")

        case .audioEngineFailed(let reason):
            return String(format: NSLocalizedString("error.audio.engineFailed", comment: "音频引擎失败"), reason)

        case .audioRecordingFailed(let reason):
            return String(format: NSLocalizedString("error.recording.failed", comment: "录音失败"), reason)

        case .audioProcessingFailed(let reason):
            return String(format: NSLocalizedString("error.audio.processingFailed", comment: "音频处理失败"), reason)

        case .transcriptionFailed(let reason):
            return String(format: NSLocalizedString("error.transcription.failed", comment: "转录失败"), reason)

        case .transcriptionEmptyResult:
            return NSLocalizedString("error.transcription.emptyResult", comment: "转录结果为空")

        case .transcriptionInvalidFormat:
            return NSLocalizedString("error.transcription.invalidFormat", comment: "转录格式无效")

        case .fileNotFound(let path):
            return String(format: NSLocalizedString("error.file.notFound", comment: "文件未找到"), path)

        case .fileEmpty(let path):
            return String(format: NSLocalizedString("error.file.empty", comment: "文件为空"), path)

        case .fileWriteFailed(let reason):
            return String(format: NSLocalizedString("error.file.writeFailed", comment: "文件写入失败"), reason)

        case .invalidState(let description):
            return String(format: NSLocalizedString("error.generic.invalidState", comment: "无效状态"), description)

        case .unknownError:
            return NSLocalizedString("error.generic.unknown", comment: "未知错误")
        }
    }

    // MARK: - 错误级别

    var type: ErrorType {
        switch self {
        case .microphonePermissionDenied,
             .microphonePermissionRestricted,
             .audioDeviceUnavailable,
             .invalidState:
            return .error

        case .networkNotConnected,
             .networkTimeout,
             .networkServerNotFound,
             .modelNotFound,
             .transcriptionEmptyResult:
            return .warning

        case .networkGeneric,
             .modelDownloadFailed,
             .modelLoadFailed,
             .audioEngineFailed,
             .audioRecordingFailed,
             .audioProcessingFailed,
             .transcriptionFailed,
             .transcriptionInvalidFormat,
             .fileNotFound,
             .fileEmpty,
             .fileWriteFailed,
             .unknownError:
            return .error
        }
    }

    // MARK: - 可恢复性

    var isRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied,
             .microphonePermissionRestricted,
             .audioDeviceUnavailable:
            return false // 需要用户操作

        case .networkNotConnected,
             .networkTimeout,
             .networkServerNotFound,
             .networkGeneric:
            return true // 可重试

        case .modelDownloadFailed,
             .modelLoadFailed,
             .modelNotFound:
            return true // 可重试

        case .audioEngineFailed,
             .audioRecordingFailed,
             .audioProcessingFailed:
            return true // 可重试

        case .transcriptionFailed,
             .transcriptionEmptyResult,
             .transcriptionInvalidFormat:
            return true // 可重试

        case .fileNotFound,
             .fileEmpty,
             .fileWriteFailed:
            return false // 需要修复文件系统

        case .invalidState,
             .unknownError:
            return true // 可重试
        }
    }

    // MARK: - 操作建议

    var suggestedAction: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("action.requestPermission", comment: "请求权限")

        case .microphonePermissionRestricted:
            return NSLocalizedString("action.openSettings", comment: "打开系统设置")

        case .networkNotConnected:
            return NSLocalizedString("action.checkConnection", comment: "检查网络连接")

        case .audioDeviceUnavailable:
            return NSLocalizedString("action.connectDevice", comment: "连接音频设备")

        case .modelDownloadFailed,
             .modelLoadFailed,
             .modelNotFound:
            return NSLocalizedString("action.retryDownload", comment: "重试下载")

        default:
            return NSLocalizedString("action.retry", comment: "重试")
        }
    }
}

// MARK: - Equatable Implementation

func == (lhs: TypelessError, rhs: TypelessError) -> Bool {
    switch (lhs, rhs) {
    case (.microphonePermissionDenied, .microphonePermissionDenied):
        return true
    case (.microphonePermissionRestricted, .microphonePermissionRestricted):
        return true
    case (.networkNotConnected, .networkNotConnected):
        return true
    case (.networkTimeout, .networkTimeout):
        return true
    case (.networkServerNotFound, .networkServerNotFound):
        return true
    case (.networkGeneric, .networkGeneric):
        return true
    case (.modelDownloadFailed(let lhsReason), .modelDownloadFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.modelLoadFailed(let lhsReason), .modelLoadFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.modelNotFound(let lhsModel), .modelNotFound(let rhsModel)):
        return lhsModel == rhsModel
    case (.audioDeviceUnavailable, .audioDeviceUnavailable):
        return true
    case (.audioEngineFailed(let lhsReason), .audioEngineFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.audioRecordingFailed(let lhsReason), .audioRecordingFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.audioProcessingFailed(let lhsReason), .audioProcessingFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.transcriptionFailed(let lhsReason), .transcriptionFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.transcriptionEmptyResult, .transcriptionEmptyResult):
        return true
    case (.transcriptionInvalidFormat, .transcriptionInvalidFormat):
        return true
    case (.fileNotFound(let lhsPath), .fileNotFound(let rhsPath)):
        return lhsPath == rhsPath
    case (.fileEmpty(let lhsPath), .fileEmpty(let rhsPath)):
        return lhsPath == rhsPath
    case (.fileWriteFailed(let lhsReason), .fileWriteFailed(let rhsReason)):
        return lhsReason == rhsReason
    case (.invalidState(let lhsDesc), .invalidState(let rhsDesc)):
        return lhsDesc == rhsDesc
    case (.unknownError, .unknownError):
        return true
    default:
        return false
    }
}

// MARK: - Error Banner View

struct ErrorBanner: View {
    let message: String
    let type: ErrorType
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
                .frame(width: 24, height: 24)

            // 消息文本
            Text(message)
                .font(.body)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color.gray.opacity(0.1))
            .clipShape(Circle())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(type.backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .padding(.horizontal)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
        )
    }
}

// MARK: - Audio Transcriber Delegate Protocol

protocol AudioTranscriberDelegate {
    func audioTranscriber(_ transcriber: AudioTranscriber, didEncounterError error: TypelessError)
    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateStatus status: String)
    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateProgress progress: Double)
}

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

// MARK: - Recording Button

struct RecordingButton: View {
    let isRecording: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulse ring when recording
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                                pulseScale = 1.3
                            }
                        }
                        .onDisappear {
                            pulseScale = 1.0
                        }
                }
                
                // Button background
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 64, height: 64)
                    .shadow(
                        color: (isRecording ? Color.red : Color.blue).opacity(0.3),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
                
                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Transcription Card

struct TranscriptionCard: View {
    let text: String
    let isEmpty: Bool
    let onCopy: () -> Void
    
    @State private var showCopiedIndicator = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Content only - no header
            ScrollView {
                Text(isEmpty ? NSLocalizedString("recording.state.ready", comment: "Ready to record") : text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 120)
            
            Divider()
            
            // Footer with copy button
            HStack {
                Spacer()
                
                if showCopiedIndicator {
                    Label("main.view.copied", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                } else if !isEmpty {
                    Button(action: {
                        onCopy()
                        withAnimation {
                            showCopiedIndicator = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopiedIndicator = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(NSLocalizedString("main.view.copy.tooltip", comment: "Copy to clipboard"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardShortcutHint: View {
    let shortcut: String
    let descriptionKey: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 6) {
            Text(shortcut)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Text(descriptionKey)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey?
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            VStack(spacing: 4) {
                Text(titleKey)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                if let subtitleKey = subtitleKey {
                    Text(subtitleKey)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Download Progress View

struct DownloadProgressView: View {
    let status: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text(status)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Processing State View

struct ProcessingStateView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }
            
            Text("main.view.processing.transcription")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording State View

struct RecordingStateView: View {
    @Binding var volumeLevel: Double
    let recordingTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 20) {
            VoiceMemoWaveformView(volumeLevel: $volumeLevel)
                .frame(height: 80)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Text(formatTime(recordingTime))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            Text("main.view.recording.instruction")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let centiseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}

// MARK: - Permission Required View

struct PermissionRequiredView: View {
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("main.view.microphone.permission.needed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("main.view.microphone.permission.description")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            Button(action: onRequestPermission) {
                Label("main.view.enable.microphone", systemImage: "mic.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - No Audio Device View

struct NoAudioDeviceView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.slash.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("main.view.no.audio.input.device.detected.title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("main.view.connect.audio.input.device.prompt")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transcription State View

struct TranscriptionStateView: View {
    let transcript: String
    let onCopy: () -> Void
    
    @State private var showCopiedIndicator = false
    
    private var isEmpty: Bool {
        transcript == NSLocalizedString("recording.state.ready", comment: "Ready to record")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(isEmpty ? NSLocalizedString("recording.state.ready", comment: "Ready to record") : transcript)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
    @AppStorage("selectedLanguage") private var uiLanguage: String = "en"
    @State private var viewRefreshID = UUID()

    // 错误系统
    @State private var currentError: TypelessError?
    @State private var showErrorBanner = false
    @State private var errorTimer: Timer?
    @State private var isUserDismissed = false
    @State private var lastError: TypelessError?
    @State private var errorCount = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            VStack(spacing: 0) {
                // Header
                HStack {
                    // App icon and title
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.accentColor)
                        
                        Text("Typeless")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showSettingsView = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(audioTranscriber.isRecording || audioTranscriber.isTranscribing || showTutorialView)
                    .help("main.view.settings.tooltip")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .opacity(showSettingsView || showTutorialView ? 0 : 1)
                
                Divider()
                    .opacity(showSettingsView || showTutorialView ? 0 : 1)
                
                // Main content area
                Group {
                    if !hasCheckedModelStatus {
                        LoadingStateView(
                            titleKey: LocalizedStringKey("main.view.checking.model.status"),
                            subtitleKey: nil
                        )
                    } else if isCheckingMicrophonePermission {
                        LoadingStateView(
                            titleKey: LocalizedStringKey("main.view.requesting.microphone.permission"),
                            subtitleKey: nil
                        )
                    } else if audioTranscriber.isDownloading || isModelDownloading {
                        DownloadProgressView(
                            status: audioTranscriber.downloadStatus,
                            progress: audioTranscriber.downloadProgress
                        )
                    } else if audioTranscriber.isTranscribing {
                        ProcessingStateView()
                    } else if isRecording {
                        RecordingStateView(
                            volumeLevel: $audioTranscriber.volumeLevel,
                            recordingTime: audioTranscriber.recordingTime
                        )
                    } else if !hasMicrophonePermission && hasRequestedMicrophonePermission {
                        PermissionRequiredView(onRequestPermission: requestMicrophonePermission)
                    } else if !hasAudioInputDevices {
                        NoAudioDeviceView()
                    } else {
                        TranscriptionStateView(
                            transcript: audioTranscriber.transcript,
                            onCopy: { copyToClipboard(audioTranscriber.transcript) }
                        )
                    }
                }
                .opacity(showSettingsView || showTutorialView ? 0 : 1)
                
                Spacer()
                
                Divider()
                    .opacity(showSettingsView || showTutorialView ? 0 : 1)
                
                // Bottom control bar
                HStack {
                    // Keyboard shortcut hint
                    if !isRecording && hasMicrophonePermission && hasAudioInputDevices && !audioTranscriber.isTranscribing {
                        KeyboardShortcutHint(
                            shortcut: "⌘R",
                            descriptionKey: LocalizedStringKey("main.view.shortcut.record")
                        )
                    }
                    
                    Spacer()
                    
                    // Recording button
                    if hasCheckedModelStatus && !isCheckingMicrophonePermission {
                        if !hasMicrophonePermission {
                            Button(action: requestMicrophonePermission) {
                                Label("main.view.enable.microphone", systemImage: "mic.fill")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        } else if hasAudioInputDevices {
                            RecordingButton(
                                isRecording: isRecording,
                                isDisabled: isModelDownloading || showTutorialView,
                                action: {
                                    toggleRecording()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(showSettingsView || showTutorialView ? 0 : 1)
            }
            .frame(width: 400, height: 300)
            
            // Settings overlay
            if showSettingsView {
                SettingsView(isPresented: $showSettingsView)
                    .environmentObject(audioTranscriber)
                    .onDisappear {
                        checkModelStatus()
                    }
            }
            
            // Tutorial overlay
            if showTutorialView {
                TutorialView(
                    isPresented: $showTutorialView,
                    onTutorialCompleted: {
                        if !hasRequestedMicrophonePermission {
                            checkMicrophonePermission()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .frame(width: 400, height: 380)
            }
            
            // Error banner
            if showErrorBanner, let error = currentError {
                ErrorBanner(
                    message: error.errorDescription ?? "Unknown error",
                    type: error.type,
                    onDismiss: dismissError
                )
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .zIndex(100)
            }
        }
        .frame(width: 400, height: 300)
        .onAppear {
            // 设置委托（仅在第一次时）
            if audioTranscriber.delegate == nil {
                audioTranscriber.delegate = self
            }

            // 检查是否需要显示教程
            let hasCompletedTutorial = UserDefaults.standard.bool(forKey: "HasCompletedTutorial")
            if !hasCompletedTutorial {
                // 延迟显示教程，确保UI已完全加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showTutorialView = true
                }
            }

            // 只有在还没有检查过麦克风权限时才检查
            if !hasRequestedMicrophonePermission {
                checkMicrophonePermission()
            }
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
                // Model status check logged to debug system
                
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
                // Model download started - app activated
            }
            
            // 註冊模型下載完成通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ModelDownloadFinished"),
                object: nil,
                queue: .main
            ) { _ in
                // 下载完成后恢复正常行为
                // Model download completed
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
        .onDisappear {
            cleanupErrorTimer()
        }
        .onChange(of: uiLanguage) {
            viewRefreshID = UUID()
        }
        .id(viewRefreshID)
    }
    
    // 检查麦克风权限
    private func checkMicrophonePermission() {
        // 如果已经请求过权限，直接检查当前状态，不再重复请求
        if hasRequestedMicrophonePermission {
            // 直接检查当前权限状态，不弹出权限对话框
            #if os(macOS)
            // 在 macOS 上使用 AVAudioApplication 检查权限
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasMicrophonePermission = granted
                    self.isCheckingMicrophonePermission = false
                }
            }
            #else
            DispatchQueue.main.async {
                self.hasMicrophonePermission = (AVAudioSession.sharedInstance().recordPermission == .granted)
                self.isCheckingMicrophonePermission = false
            }
            #endif
            return
        }
        
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
        // 如果已经请求过权限，直接检查当前状态
        if hasRequestedMicrophonePermission {
            #if os(macOS)
            // 在 macOS 上使用 AVAudioApplication 检查权限
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasMicrophonePermission = granted
                    self.isCheckingMicrophonePermission = false
                    
                    if !self.hasMicrophonePermission {
                        // 显示系统设置提示
                        let alert = NSAlert()
                        alert.messageText = NSLocalizedString("main.view.microphone.permission.needed.alert.title", comment: "")
                        alert.informativeText = NSLocalizedString("main.view.microphone.permission.needed.alert.message", comment: "")
                        alert.addButton(withTitle: NSLocalizedString("main.view.open.settings.button", comment: ""))
                        alert.addButton(withTitle: NSLocalizedString("general.cancel.button", comment: ""))
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                        }
                    }
                }
            }
            #else
            DispatchQueue.main.async {
                self.hasMicrophonePermission = (AVAudioSession.sharedInstance().recordPermission == .granted)
                self.isCheckingMicrophonePermission = false
                
                if !self.hasMicrophonePermission {
                    // 显示系统设置提示
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("main.view.microphone.permission.needed.alert.title", comment: "")
                    alert.informativeText = NSLocalizedString("main.view.microphone.permission.needed.alert.message", comment: "")
                    alert.addButton(withTitle: NSLocalizedString("main.view.open.settings.button", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("general.cancel.button", comment: ""))
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                    }
                }
            }
            #endif
            return
        }
        
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
                    alert.messageText = NSLocalizedString("main.view.microphone.permission.needed.alert.title", comment: "")
                    alert.informativeText = NSLocalizedString("main.view.microphone.permission.needed.alert.message", comment: "")
                    alert.addButton(withTitle: NSLocalizedString("main.view.open.settings.button", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("general.cancel.button", comment: ""))
                    
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
        // Model status check logged to debug system
        
        // 如果模型未下载，自动开始下载
        if !isDownloaded {
            // Model not downloaded, preparing to download
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
        // Model status check logged to debug system
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
            // Model already downloading, skipping duplicate request
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
    
    // Toggle recording state
    private func toggleRecording() {
        if hasMicrophonePermission {
            isRecording.toggle()
            if isRecording {
                audioTranscriber.setModel(selectedModel)
                if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                    audioTranscriber.setLanguage(savedLanguage)
                }
                audioTranscriber.startRecording()
            } else {
                audioTranscriber.stopRecording()
            }
        } else {
            requestMicrophonePermission()
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
                content.title = NSLocalizedString("main.view.copied.notification.title", comment: "")
                content.body = NSLocalizedString("main.view.copied.notification.body", comment: "")
                content.sound = .default
                
                let request = UNNotificationRequest(identifier: "CopyToClipboard", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        // Notification failed to send
                    }
                }
            } else if let error = error {
                // Notification permission denied
            }
        }
    }
    
    // 格式化时间显示
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let centiseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)  // 百分之一秒
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    // MARK: - Error Handling Methods

    // 处理错误
    private func handleError(_ error: TypelessError) {
        print("❌ Error occurred: \(error.errorDescription ?? "Unknown")")

        // 检测重复错误
        if lastError == error {
            errorCount += 1
            if errorCount >= 3 {
                // 连续 3 次相同错误，延长显示时间
                showInfo("重复错误: \(error.errorDescription ?? "Unknown")")
                return
            }
        } else {
            errorCount = 1
            lastError = error
        }

        currentError = error
        isUserDismissed = false

        withAnimation {
            showErrorBanner = true
        }

        // 清理之前的定时器
        errorTimer?.invalidate()

        // 根据错误类型设置不同的显示时间
        let displayDuration: TimeInterval
        switch error.type {
        case .error: displayDuration = 5.0
        case .warning: displayDuration = 3.0
        case .info: displayDuration = 2.0
        }

        // 自动消失（仅对可恢复错误）
        if error.isRecoverable {
            errorTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { _ in
                if !self.isUserDismissed {
                    withAnimation {
                        self.showErrorBanner = false
                    }
                }
            }
        }
    }

    // 显示信息
    private func showInfo(_ message: String) {
        currentError = .invalidState(description: message)
        isUserDismissed = false

        withAnimation {
            showErrorBanner = true
        }

        errorTimer?.invalidate()
        errorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            if !self.isUserDismissed {
                withAnimation {
                    self.showErrorBanner = false
                }
            }
        }
    }

    // 隐藏错误
    private func dismissError() {
        isUserDismissed = true
        errorTimer?.invalidate()
        errorTimer = nil

        withAnimation {
            showErrorBanner = false
        }
    }

    // 清理错误定时器
    private func cleanupErrorTimer() {
        errorTimer?.invalidate()
        errorTimer = nil
    }
}

// MARK: - AudioTranscriberDelegate Implementation

extension MainView: AudioTranscriberDelegate {
    func audioTranscriber(_ transcriber: AudioTranscriber, didEncounterError error: TypelessError) {
        handleError(error)
    }

    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateStatus status: String) {
        // Status updates are handled through published properties
        // This delegate method can be used for additional status handling if needed
        print("Status update: \(status)")
    }

    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateProgress progress: Double) {
        // Progress updates are handled through published properties
        // This delegate method can be used for additional progress handling if needed
        print("Progress update: \(progress)")
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
                    // Model selected
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
                Text("general.quit.button")
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
