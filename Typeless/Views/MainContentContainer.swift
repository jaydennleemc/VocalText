//
//  MainContentContainer.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Main Content Container

struct MainContentContainer: View {
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
                isEmpty: !transcriber.hasValidTranscript,
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
