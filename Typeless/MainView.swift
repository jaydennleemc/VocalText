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

// MARK: - Error Banner View

struct ErrorBanner: View {
    let message: String
    let type: ErrorType
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
                .frame(width: 24, height: 24)

            Text(message)
                .font(.body)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

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

// MARK: - Waveform Views

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
        .background(Color.primary.opacity(0.04))
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
    @StateObject private var audioTranscriber = AudioTranscriber.shared
    @StateObject private var appState = AppState()
    @State private var selectedModel = "Tiny" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        }
    }
    @State private var hasCheckedModelStatus = false
    @State private var isDownloadingModel = false
    @AppStorage("selectedLanguage") private var uiLanguage: String = "en"
    @State private var viewRefreshID = UUID()

    // Quick record state
    @State private var isQuickRecording = false
    @State private var quickRecordStartTime: Date?
    @State private var quickRecordCopied = false

    private let minimumRecordingDuration: TimeInterval = AppConstants.QuickRecord.minimumDuration

    var body: some View {
        let state = appState
        let transcriber = audioTranscriber
        return ZStack(alignment: .top) {
            MainContentContainer(
                state: state,
                transcriber: transcriber,
                hasCheckedModelStatus: hasCheckedModelStatus,
                isDownloadingModel: isDownloadingModel,
                selectedModel: selectedModel,
                onCopy: { copyToClipboard(transcriber.transcript) },
                onToggleRecording: { toggleRecording() },
                onRequestPermission: { transcriber.requestMicrophonePermission() }
            )
            .opacity(state.navigation == .main ? 1 : 0)

            // Settings overlay
            if state.navigation == .settings {
                SettingsView(isPresented: Binding(
                    get: { state.navigation == .settings },
                    set: { if !$0 { state.navigate(to: .main) } }
                ))
                .environmentObject(transcriber)
                .onDisappear { checkModelStatus() }
            }

            // Tutorial overlay
            if state.navigation == .tutorial {
                TutorialView(
                    isPresented: Binding(
                        get: { state.navigation == .tutorial },
                        set: { if !$0 { state.navigate(to: .main) } }
                    ),
                    onTutorialCompleted: {
                        if !transcriber.permissionManager.hasRequestedPermission {
                            transcriber.checkMicrophonePermission()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .frame(width: 400, height: 380)
            }

            // Error banner
            if state.showErrorBanner, let error = state.currentError {
                ErrorBanner(
                    message: error.errorDescription ?? "Unknown error",
                    type: error.type,
                    onDismiss: { state.dismissError() }
                )
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .zIndex(100)
            }
        }
        .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.windowHeight)
        .onAppear { setupOnAppear() }
        .onDisappear { appState.cleanupErrorTimer() }
        .onReceive(NotificationCenter.default.publisher(for: .modelChanged)) { _ in
            if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
                selectedModel = savedModel
            }
            let isDownloaded = audioTranscriber.isModelAlreadyDownloaded(model: selectedModel.lowercased())
            hasCheckedModelStatus = true
            if isDownloaded { Task { await audioTranscriber.preloadWhisperKit() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .modelDownloadRequested)) { notification in
            if let model = notification.object as? String { downloadModel(model: model) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .modelDownloadStarted)) { _ in
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startQuickRecord)) { _ in
            handleStartQuickRecord()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopQuickRecord)) { _ in
            handleStopQuickRecord()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcribingStopped)) { _ in
            handleTranscribingStoppedForQuickRecord()
        }
        .onChange(of: uiLanguage) { viewRefreshID = UUID() }
        .id(viewRefreshID)
    }

    // MARK: - Setup

    private func setupOnAppear() {
        if audioTranscriber.delegate == nil {
            audioTranscriber.delegate = appState
        }

        let hasCompletedTutorial = UserDefaults.standard.bool(forKey: "HasCompletedTutorial")
        if !hasCompletedTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.navigate(to: .tutorial)
            }
        }

        if !audioTranscriber.permissionManager.hasRequestedPermission {
            audioTranscriber.checkMicrophonePermission()
        }
        audioTranscriber.getAvailableAudioDevices()

        if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
            selectedModel = savedModel
        }

        checkModelStatus()

        // Delayed device/language setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let savedDeviceIndex = UserDefaults.standard.integer(forKey: "SelectedDeviceIndex")
            if savedDeviceIndex < audioTranscriber.audioDevices.count {
                audioTranscriber.setSelectedDevice(index: savedDeviceIndex)
            }
            if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                audioTranscriber.setLanguage(savedLanguage)
            }
        }
    }

    // MARK: - Model Management

    private func checkModelStatus() {
        let isDownloaded = audioTranscriber.isModelAlreadyDownloaded(model: selectedModel.lowercased())
        hasCheckedModelStatus = true
        if !isDownloaded {
            downloadModel(model: selectedModel)
        }
        if isDownloaded {
            Task { await audioTranscriber.preloadWhisperKit() }
        }
    }

    private func downloadModel(model: String) {
        guard !isDownloadingModel else { return }
        audioTranscriber.setModel(model)
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            audioTranscriber.setLanguage(savedLanguage)
        }
        isDownloadingModel = true
        NSApp.activate(ignoringOtherApps: true)
        Task {
            let success = await audioTranscriber.checkAndDownloadModelIfNeeded()
            await MainActor.run {
                isDownloadingModel = false
                if success {
                    Task { await audioTranscriber.preloadWhisperKit() }
                    NotificationCenter.default.post(name: .modelChanged, object: nil)
                }
            }
        }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if audioTranscriber.hasMicrophonePermission {
            if audioTranscriber.isRecording {
                audioTranscriber.stopRecording()
            } else {
                audioTranscriber.setModel(selectedModel)
                if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                    audioTranscriber.setLanguage(savedLanguage)
                }
                audioTranscriber.startRecording()
            }
        } else {
            audioTranscriber.requestMicrophonePermission()
        }
    }

    // MARK: - Clipboard

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("main.view.copied.notification.title", comment: "")
                content.body = NSLocalizedString("main.view.copied.notification.body", comment: "")
                content.sound = .default
                let request = UNNotificationRequest(identifier: "CopyToClipboard", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Quick Record

    private func handleStartQuickRecord() {
        guard !audioTranscriber.isTranscribing else { return }
        if audioTranscriber.isRecording {
            audioTranscriber.stopRecording()
        }
        isQuickRecording = true
        quickRecordStartTime = Date()
        quickRecordCopied = false
        if audioTranscriber.hasMicrophonePermission {
            audioTranscriber.setModel(selectedModel)
            if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                audioTranscriber.setLanguage(savedLanguage)
            }
            audioTranscriber.startRecording()
        } else {
            audioTranscriber.requestMicrophonePermission()
        }
    }

    private func handleStopQuickRecord() {
        guard isQuickRecording, let startTime = quickRecordStartTime else {
            isQuickRecording = false
            return
        }
        let duration = Date().timeIntervalSince(startTime)
        if duration < minimumRecordingDuration {
            if audioTranscriber.isRecording { audioTranscriber.stopRecording() }
            isQuickRecording = false
            quickRecordStartTime = nil
            return
        }
        if audioTranscriber.isRecording { audioTranscriber.stopRecording() }
    }

    private func handleTranscribingStoppedForQuickRecord() {
        guard isQuickRecording, !quickRecordCopied else { return }
        let text = audioTranscriber.transcript
        let isEmpty = text == NSLocalizedString("recording.state.ready", comment: "") ||
                      text.isEmpty ||
                      text == NSLocalizedString("error.transcription.emptyResult", comment: "")
        if isEmpty {
            isQuickRecording = false
            quickRecordStartTime = nil
            return
        }
        quickRecordCopied = true
        copyToClipboard(text)
        isQuickRecording = false
        quickRecordStartTime = nil
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let modelChanged = Notification.Name("ModelChanged")
    static let modelDownloadRequested = Notification.Name("ModelDownloadRequested")
    static let modelDownloadStarted = Notification.Name("ModelDownloadStarted")
    static let modelDownloadFinished = Notification.Name("ModelDownloadFinished")
    static let modelErrorOccurred = Notification.Name("ModelErrorOccurred")
    static let startQuickRecord = Notification.Name("StartQuickRecord")
    static let stopQuickRecord = Notification.Name("StopQuickRecord")
    static let transcribingStarted = Notification.Name("TranscribingStarted")
    static let transcribingStopped = Notification.Name("TranscribingStopped")
    static let transcriptionError = Notification.Name("TranscriptionError")
    static let audioDevicesChanged = Notification.Name("AudioDevicesChanged")
    static let recordingStarted = Notification.Name("RecordingStarted")
    static let recordingStopped = Notification.Name("RecordingStopped")
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

// MARK: - Main Content Container

private struct MainContentContainer: View {
    @ObservedObject var state: AppState
    @ObservedObject var transcriber: AudioTranscriber
    let hasCheckedModelStatus: Bool
    let isDownloadingModel: Bool
    let selectedModel: String
    let onCopy: () -> Void
    let onToggleRecording: () -> Void
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentArea
            Spacer()
            bottomBar
        }
        .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.windowHeight)
        .background(Color.primary.opacity(0.02))
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Typeless")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
            Button(action: { state.navigate(to: .settings) }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(transcriber.isRecording || transcriber.isTranscribing || state.navigation == .tutorial)
            .help("main.view.settings.tooltip")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var contentArea: some View {
        if !hasCheckedModelStatus {
            LoadingStateView(
                titleKey: LocalizedStringKey("main.view.checking.model.status"),
                subtitleKey: nil
            )
        } else if transcriber.isCheckingPermission {
            LoadingStateView(
                titleKey: LocalizedStringKey("main.view.requesting.microphone.permission"),
                subtitleKey: nil
            )
        } else if transcriber.isDownloading || isDownloadingModel {
            DownloadProgressView(
                status: transcriber.downloadStatus,
                progress: transcriber.downloadProgress
            )
        } else if transcriber.isTranscribing {
            ProcessingStateView()
        } else if transcriber.isRecording {
            RecordingStateView(
                volumeLevel: $transcriber.volumeLevel,
                recordingTime: transcriber.recordingTime
            )
        } else if !transcriber.hasMicrophonePermission && transcriber.permissionManager.hasRequestedPermission {
            PermissionRequiredView(onRequestPermission: onRequestPermission)
        } else if !transcriber.hasAvailableAudioInputDevices() {
            NoAudioDeviceView()
        } else {
            TranscriptionCard(
                text: transcriber.transcript,
                isEmpty: transcriber.transcript == NSLocalizedString("recording.state.ready", comment: "Ready to record"),
                onCopy: onCopy
            )
        }
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            if hasCheckedModelStatus && !transcriber.isCheckingPermission {
                if !transcriber.hasMicrophonePermission {
                    Button(action: onRequestPermission) {
                        Label("main.view.enable.microphone", systemImage: "mic.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if transcriber.hasAvailableAudioInputDevices() {
                    RecordingButton(
                        isRecording: transcriber.isRecording,
                        isDisabled: isDownloadingModel || state.navigation == .tutorial,
                        action: onToggleRecording
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
