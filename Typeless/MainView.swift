//
//  MainView.swift
//  Typeless
//

import SwiftUI
import AppKit

struct MainView: View {
    @StateObject private var audioTranscriber = AudioTranscriber.shared
    @State private var selectedModel = "Tiny" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "SelectedModel") }
    }
    @State private var hasCheckedModelStatus = false
    @State private var isDownloadingModel = false
    @AppStorage("selectedLanguage") private var uiLanguage: String = "en"
    @State private var viewRefreshID = UUID()

    var body: some View {
        ZStack(alignment: .top) {
            MainContentContainer(
                transcriber: audioTranscriber,
                hasCheckedModelStatus: hasCheckedModelStatus,
                isDownloadingModel: isDownloadingModel,
                selectedModel: $selectedModel,
                onCopy: { audioTranscriber.copyTranscriptToClipboard() },
                onToggleRecording: { toggleRecording() },
                onRequestPermission: { audioTranscriber.requestMicrophonePermission() },
                onOpenHistory: { AppWindows.openHistory() },
                onOpenSettings: { AppWindows.openSettings() }
            )

            if audioTranscriber.showErrorBanner, let error = audioTranscriber.currentError {
                ErrorBanner(
                    message: error.errorDescription ?? "Unknown error",
                    type: error.type,
                    onDismiss: { audioTranscriber.dismissError() }
                )
                .padding(.top, 10)
                .padding(.horizontal, 12)
                .zIndex(100)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 420, height: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { setupOnAppear() }
        .onDisappear { audioTranscriber.cleanupErrorTimer() }
        .onChange(of: uiLanguage) { viewRefreshID = UUID() }
        .id(viewRefreshID)
        .sheet(isPresented: Binding(
            get: { audioTranscriber.navigation == .tutorial },
            set: { if !$0 { audioTranscriber.navigate(to: .main) } }
        )) {
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
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: audioTranscriber.navigation)
    }

    // MARK: - Setup

    private func setupOnAppear() {
        if !UserDefaults.standard.bool(forKey: "HasCompletedTutorial") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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

    // MARK: - Model

    private func checkModelStatus() {
        if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
            selectedModel = savedModel
        }
        let isDownloaded = audioTranscriber.isModelAlreadyDownloaded(model: selectedModel.lowercased())
        hasCheckedModelStatus = true
        if !isDownloaded {
            downloadModel(model: selectedModel)
        } else {
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
                }
            }
        }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if audioTranscriber.hasMicrophonePermission {
            if !audioTranscriber.isRecording {
                audioTranscriber.setModel(selectedModel)
                if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
                    audioTranscriber.setLanguage(savedLanguage)
                }
            }
            audioTranscriber.toggleRecording()
        } else {
            audioTranscriber.requestMicrophonePermission()
        }
    }
}

