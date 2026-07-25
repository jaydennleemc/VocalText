//
//  MainContentContainer.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Main Content Container

struct MainContentContainer: View {
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
            Divider().overlay(Color(nsColor: .separatorColor))
            contentArea
            Divider().overlay(Color(nsColor: .separatorColor))
            bottomBar
        }
        .frame(width: 400, height: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 22, height: 22)
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Typeless")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
            Button(action: { transcriber.navigate(to: .settings) }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(transcriber.isRecording || transcriber.isTranscribing || transcriber.navigation == .tutorial)
            .opacity((transcriber.isRecording || transcriber.isTranscribing || transcriber.navigation == .tutorial) ? 0.4 : 1.0)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                volumeLevel: transcriber.volumeLevel,
                recordingTime: transcriber.recordingTime
            )
        } else if !transcriber.hasMicrophonePermission && transcriber.permissionManager.hasRequestedPermission {
            PermissionRequiredView(onRequestPermission: onRequestPermission)
        } else if !transcriber.hasAvailableAudioInputDevices() {
            NoAudioDeviceView()
        } else {
            TranscriptionCard(
                text: transcriber.transcript,
                isEmpty: !transcriber.hasValidTranscript,
                onCopy: onCopy
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            if hasCheckedModelStatus && !transcriber.isCheckingPermission {
                if !transcriber.hasMicrophonePermission {
                    Button(action: onRequestPermission) {
                        Label("Enable Microphone", systemImage: "mic.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                } else if transcriber.hasAvailableAudioInputDevices() {
                    RecordingButton(
                        isRecording: transcriber.isRecording,
                        isDisabled: isDownloadingModel || transcriber.navigation == .tutorial,
                        action: onToggleRecording
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
