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
        HStack(spacing: AppConstants.UI.spacingSM) {
            Image(systemName: type.icon)
                .font(.system(size: AppConstants.UI.iconMedium))
                .foregroundColor(type.color)
                .frame(width: 24, height: 24)

            Text(message)
                .font(.system(size: AppConstants.UI.fontBodyLarge))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color.bgHover)
            .clipShape(Circle())
        }
        .padding(.vertical, AppConstants.UI.spacingSM)
        .padding(.horizontal, AppConstants.UI.spacingMD)
        .background(type.backgroundColor)
        .cornerRadius(AppConstants.UI.radiusSM)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, AppConstants.UI.spacingSM)
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
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: AppConstants.Recording.waveformBarCount)
    @State private var lastVolumeUpdate: Date = Date()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.recordingRed, .recordingRed.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: AppConstants.UI.waveformBarWidth, height: max(2, bars[index] * AppConstants.UI.waveformHeight))
                    .animation(.easeOut(duration: AppConstants.Animation.waveformBarDuration), value: bars[index])
            }
        }
        .frame(height: AppConstants.UI.waveformHeight)
        .onReceive(Timer.publish(every: AppConstants.Recording.waveformTimerInterval, on: .main, in: .common).autoconnect()) { _ in
            updateBars()
        }
        .onChange(of: volumeLevel) { _ in
            updateBarsWithVolume()
        }
    }

    private func updateBars() {
        bars.removeFirst()
        let newBarHeight = CGFloat(volumeLevel)
        bars.append(newBarHeight)

        if bars.count >= 3 {
            for i in 1..<bars.count-1 {
                bars[i] = (bars[i-1] + bars[i] + bars[i+1]) / 3
            }
        }
    }

    private func updateBarsWithVolume() {
        if !bars.isEmpty {
            let randomFactor = Double.random(in: 0.8...1.2)
            let adjustedVolume = volumeLevel * randomFactor
            let newBarHeight = CGFloat(min(1.0, adjustedVolume))
            bars[bars.count - 1] = newBarHeight

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
                        .stroke(Color.recordingGlow, lineWidth: 2)
                        .frame(width: AppConstants.UI.recordButtonRingSize + 8, height: AppConstants.UI.recordButtonRingSize + 8)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: AppConstants.Animation.pulseRingDuration).repeatForever(autoreverses: false)) {
                                pulseScale = 1.3
                            }
                        }
                        .onDisappear {
                            pulseScale = 1.0
                        }
                }

                // Button background with gradient
                Circle()
                    .fill(isRecording ? AnyShapeStyle(Color.recordingGradient) : AnyShapeStyle(Color.accentGradient))
                    .frame(width: AppConstants.UI.recordButtonSize, height: AppConstants.UI.recordButtonSize)
                    .shadow(
                        color: (isRecording ? Color.recordingGlow : Color.accentGlow),
                        radius: isPressed ? 6 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )

                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: AppConstants.Animation.buttonPressDuration), value: isPressed)
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
        HStack(spacing: AppConstants.UI.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: AppConstants.UI.iconMedium))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: AppConstants.UI.fontBody, weight: .semibold))
                    .foregroundColor(.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: AppConstants.UI.fontCaption))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppConstants.UI.spacingSM)
        .padding(.vertical, AppConstants.UI.spacingXS)
        .cardStyle()
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
            ScrollView {
                Text(isEmpty ? NSLocalizedString("recording.state.ready", comment: "Ready to record") : text)
                    .font(.system(size: AppConstants.UI.fontBodyLarge))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .textTertiary : .textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppConstants.UI.spacingSM)
            }
            .frame(maxHeight: AppConstants.UI.transcriptMaxHeight)

            SectionDivider()

            // Footer with copy button
            HStack {
                Spacer()

                if showCopiedIndicator {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                        Text("main.view.copied")
                            .font(.system(size: AppConstants.UI.fontCaption, weight: .medium))
                    }
                    .foregroundColor(.successGreen)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if !isEmpty {
                    Button(action: {
                        onCopy()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopiedIndicator = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.copiedIndicatorDuration) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopiedIndicator = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: AppConstants.UI.iconSmall))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(NSLocalizedString("main.view.copy.tooltip", comment: "Copy to clipboard"))
                }
            }
            .padding(.horizontal, AppConstants.UI.spacingSM)
            .padding(.vertical, AppConstants.UI.spacingXS)
            .background(Color.bgHover.opacity(0.5))
        }
        .cardStyle()
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardShortcutHint: View {
    let shortcut: String
    let descriptionKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            Text(shortcut)
                .font(.system(size: AppConstants.UI.fontCaption, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.bgHover)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(descriptionKey)
                .font(.system(size: AppConstants.UI.fontCaption))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey?

    var body: some View {
        VStack(spacing: AppConstants.UI.spacingMD) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .tint(.accentPrimary)

            VStack(spacing: AppConstants.UI.spacingXXS) {
                Text(titleKey)
                    .font(.system(size: AppConstants.UI.fontBodyLarge, weight: .medium))
                    .foregroundColor(.textPrimary)

                if let subtitleKey = subtitleKey {
                    Text(subtitleKey)
                        .font(.system(size: AppConstants.UI.fontBody))
                        .foregroundColor(.textSecondary)
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
        VStack(spacing: AppConstants.UI.spacingLG) {
            IconContainer(
                icon: "arrow.down.circle.fill",
                color: .accentPrimary,
                size: AppConstants.UI.stateIconSize,
                radius: AppConstants.UI.stateIconRadius
            )

            VStack(spacing: AppConstants.UI.spacingXS) {
                Text(status)
                    .font(.system(size: AppConstants.UI.fontBodyLarge, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.accentPrimary)
                    .frame(width: 200)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: AppConstants.UI.fontBody, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Processing State View

struct ProcessingStateView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: AppConstants.UI.spacingMD) {
            ZStack {
                Circle()
                    .stroke(Color.bgHover, lineWidth: 3)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: AppConstants.Animation.spinnerDuration).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }

            Text("main.view.processing.transcription")
                .font(.system(size: AppConstants.UI.fontBodyLarge, weight: .medium))
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording State View

struct RecordingStateView: View {
    @Binding var volumeLevel: Double
    let recordingTime: TimeInterval

    var body: some View {
        VStack(spacing: AppConstants.UI.spacingLG) {
            VoiceMemoWaveformView(volumeLevel: $volumeLevel)
                .frame(height: AppConstants.UI.waveformHeight + 10)

            HStack(spacing: AppConstants.UI.spacingXS) {
                Circle()
                    .fill(Color.recordingRed)
                    .frame(width: 8, height: 8)

                Text(formatTime(recordingTime))
                    .font(.system(size: AppConstants.UI.fontTimer, weight: .medium, design: .monospaced))
                    .foregroundColor(.textPrimary)
            }

            Text("main.view.recording.instruction")
                .font(.system(size: AppConstants.UI.fontBody))
                .foregroundColor(.textSecondary)
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
        VStack(spacing: AppConstants.UI.spacingMD) {
            IconContainer(
                icon: "mic.slash.circle.fill",
                color: .warningOrange,
                size: AppConstants.UI.stateIconSize,
                radius: AppConstants.UI.stateIconRadius
            )

            VStack(spacing: AppConstants.UI.spacingXS) {
                Text("main.view.microphone.permission.needed")
                    .font(.system(size: AppConstants.UI.fontSectionTitle, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("main.view.microphone.permission.description")
                    .font(.system(size: AppConstants.UI.fontBody))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: onRequestPermission) {
                Label("main.view.enable.microphone", systemImage: "mic.fill")
                    .font(.system(size: AppConstants.UI.fontBody, weight: .medium))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, AppConstants.UI.spacingXS)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - No Audio Device View

struct NoAudioDeviceView: View {
    var body: some View {
        VStack(spacing: AppConstants.UI.spacingMD) {
            IconContainer(
                icon: "speaker.slash.circle.fill",
                color: .textTertiary,
                size: AppConstants.UI.stateIconSize,
                radius: AppConstants.UI.stateIconRadius
            )

            VStack(spacing: AppConstants.UI.spacingXS) {
                Text("main.view.no.audio.input.device.detected.title")
                    .font(.system(size: AppConstants.UI.fontSectionTitle, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("main.view.connect.audio.input.device.prompt")
                    .font(.system(size: AppConstants.UI.fontBody))
                    .foregroundColor(.textSecondary)
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
                    .font(.system(size: AppConstants.UI.fontBodyLarge))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .textTertiary : .textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppConstants.UI.spacingSM)
                    .padding(.vertical, AppConstants.UI.spacingXS)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, AppConstants.UI.spacingMD)
        .padding(.vertical, AppConstants.UI.spacingXS)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppConstants.UI.spacingMD)
            .padding(.vertical, AppConstants.UI.spacingXS)
            .background(Color.accentGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: AppConstants.Animation.buttonPressDuration), value: configuration.isPressed)
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
            // Background
            Color.bgPrimary
                .ignoresSafeArea()

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
                .transition(.opacity)
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
                .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.tutorialHeight)
            }

            // Error banner
            if state.showErrorBanner, let error = state.currentError {
                ErrorBanner(
                    message: error.errorDescription ?? "Unknown error",
                    type: error.type,
                    onDismiss: { state.dismissError() }
                )
                .padding(.top, AppConstants.UI.spacingXS)
                .padding(.horizontal, AppConstants.UI.spacingSM)
                .zIndex(100)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.windowHeight)
        .background(Color.bgPrimary)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Tutorial.showDelay) {
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

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Device.deviceLoadDelay) {
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
            Divider().overlay(Color.borderPrimary)
            contentArea
            Divider().overlay(Color.borderPrimary)
            bottomBar
        }
        .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.windowHeight)
        .background(Color.bgPrimary)
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: AppConstants.UI.spacingXS) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppConstants.UI.headerIconRadius)
                        .fill(Color.accentGradient)
                        .frame(width: AppConstants.UI.headerIconSize, height: AppConstants.UI.headerIconSize)
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Typeless")
                    .font(.system(size: AppConstants.UI.fontHeader, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            Button(action: { state.navigate(to: .settings) }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: AppConstants.UI.iconSmall))
                    .foregroundColor(.textTertiary)
                    .frame(width: AppConstants.UI.headerButtonSize, height: AppConstants.UI.headerButtonSize)
                    .background(Color.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(transcriber.isRecording || transcriber.isTranscribing || state.navigation == .tutorial)
            .opacity((transcriber.isRecording || transcriber.isTranscribing || state.navigation == .tutorial) ? 0.4 : 1.0)
            .help("main.view.settings.tooltip")
        }
        .padding(.horizontal, AppConstants.UI.spacingMD)
        .padding(.vertical, AppConstants.UI.spacingSM)
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
            .padding(.horizontal, AppConstants.UI.spacingMD)
            .padding(.vertical, AppConstants.UI.spacingSM)
        }
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            if hasCheckedModelStatus && !transcriber.isCheckingPermission {
                if !transcriber.hasMicrophonePermission {
                    Button(action: onRequestPermission) {
                        Label("main.view.enable.microphone", systemImage: "mic.fill")
                            .font(.system(size: AppConstants.UI.fontBody, weight: .medium))
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
        .padding(.horizontal, AppConstants.UI.spacingMD)
        .padding(.vertical, AppConstants.UI.spacingSM)
    }
}
