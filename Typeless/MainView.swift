//
//  MainView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import AppKit
import UserNotifications

struct MainView: View {
    @StateObject private var audioTranscriber = AudioTranscriber.shared
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

    private let minimumRecordingDuration: TimeInterval = 0.5

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            MainContentContainer(
                transcriber: audioTranscriber,
                hasCheckedModelStatus: hasCheckedModelStatus,
                isDownloadingModel: isDownloadingModel,
                selectedModel: selectedModel,
                onCopy: { copyToClipboard(audioTranscriber.transcript) },
                onToggleRecording: { toggleRecording() },
                onRequestPermission: { audioTranscriber.requestMicrophonePermission() }
            )
            .opacity(audioTranscriber.navigation == .main ? 1 : 0)

            // Settings overlay
            if audioTranscriber.navigation == .settings {
                SettingsView(isPresented: Binding(
                    get: { audioTranscriber.navigation == .settings },
                    set: { if !$0 { audioTranscriber.navigate(to: .main) } }
                ))
                .environmentObject(audioTranscriber)
                .onDisappear { checkModelStatus() }
                .transition(.opacity)
            }

            // Tutorial overlay
            if audioTranscriber.navigation == .tutorial {
                TutorialView(
                    isPresented: Binding(
                        get: { audioTranscriber.navigation == .tutorial },
                        set: { if !$0 { audioTranscriber.navigate(to: .main) } }
                    ),
                    onTutorialCompleted: {
                        if !audioTranscriber.permissionManager.hasRequestedPermission {
                            audioTranscriber.checkMicrophonePermission()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .frame(width: 400, height: 380)
            }

            // Error banner
            if audioTranscriber.showErrorBanner, let error = audioTranscriber.currentError {
                ErrorBanner(
                    message: error.errorDescription ?? "Unknown error",
                    type: error.type,
                    onDismiss: { audioTranscriber.dismissError() }
                )
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .zIndex(100)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .frame(width: 400, height: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { setupOnAppear() }
        .onDisappear { audioTranscriber.cleanupErrorTimer() }
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
        // AudioTranscriber now handles errors internally

        let hasCompletedTutorial = UserDefaults.standard.bool(forKey: "HasCompletedTutorial")
        if !hasCompletedTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                audioTranscriber.navigate(to: .tutorial)
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
        audioTranscriber.startQuickRecord()
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
            audioTranscriber.stopQuickRecord()
            return
        }
        let duration = Date().timeIntervalSince(startTime)
        if duration < minimumRecordingDuration {
            if audioTranscriber.isRecording { audioTranscriber.stopRecording() }
            isQuickRecording = false
            quickRecordStartTime = nil
            audioTranscriber.stopQuickRecord()
            return
        }
        if audioTranscriber.isRecording { audioTranscriber.stopRecording() }
    }

    private func handleTranscribingStoppedForQuickRecord() {
        guard isQuickRecording, !quickRecordCopied else { return }
        let text = audioTranscriber.transcript
        let hasContent = audioTranscriber.hasValidTranscript && !text.isEmpty
        if !hasContent {
            isQuickRecording = false
            quickRecordStartTime = nil
            audioTranscriber.stopQuickRecord()
            return
        }
        quickRecordCopied = true
        audioTranscriber.markQuickRecordCopied()
        copyToClipboard(text)
        isQuickRecording = false
        quickRecordStartTime = nil
        audioTranscriber.stopQuickRecord()
    }
}