//
//  MainContentContainer.swift
//  Typeless
//

import SwiftUI

// MARK: - Main Content Container

struct MainContentContainer: View {
    @ObservedObject var transcriber: AudioTranscriber
    let hasCheckedModelStatus: Bool
    let isDownloadingModel: Bool
    @Binding var selectedModel: String
    let onCopy: () -> Void
    let onToggleRecording: () -> Void
    let onRequestPermission: () -> Void
    var onOpenHistory: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canRecord: Bool {
        hasCheckedModelStatus
            && !transcriber.isCheckingPermission
            && !isDownloadingModel
            && !transcriber.isDownloading
            && transcriber.hasMicrophonePermission
            && transcriber.hasAvailableAudioInputDevices()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stateRegion
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsResultChrome {
                resultFooter
            }
            Divider().opacity(0.35)
            QuickSettingsBar(
                transcriber: transcriber,
                selectedModel: $selectedModel,
                onOpenAllSettings: {
                    if let onOpenSettings {
                        onOpenSettings()
                    } else {
                        transcriber.navigate(to: .settings)
                    }
                }
            )
            Divider().opacity(0.25)
            primaryBar
        }
        .frame(width: 420, height: 380)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text("Typeless")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                headerIconButton("clock.arrow.circlepath", help: "History") {
                    onOpenHistory?()
                }

                headerIconButton("gearshape", help: "Settings") {
                    if let onOpenSettings {
                        onOpenSettings()
                    } else {
                        transcriber.navigate(to: .settings)
                    }
                }
                .disabled(transcriber.isRecording || transcriber.isTranscribing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func headerIconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - State region

    @ViewBuilder
    private var stateRegion: some View {
        Group {
            if !hasCheckedModelStatus || transcriber.isCheckingPermission {
                StatusPlaceholder(
                    symbol: "ellipsis.circle",
                    title: hasCheckedModelStatus
                        ? NSLocalizedString("main.view.requesting.microphone.permission", comment: "")
                        : NSLocalizedString("main.view.checking.model.status", comment: ""),
                    subtitle: nil
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
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.9), value: stateAnimationKey)
    }

    private var stateAnimationKey: String {
        if transcriber.isRecording { return "rec" }
        if transcriber.isTranscribing { return "tx" }
        if transcriber.isDownloading || isDownloadingModel { return "dl" }
        if !transcriber.hasMicrophonePermission { return "mic" }
        return "idle"
    }

    private var showsResultChrome: Bool {
        canRecord && !transcriber.isRecording && !transcriber.isTranscribing && transcriber.hasValidTranscript
    }

    private var resultFooter: some View {
        HStack {
            Label("Ready to copy", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            Spacer()
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("c", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Primary bar

    private var primaryBar: some View {
        HStack {
            Spacer()
            if hasCheckedModelStatus && !transcriber.isCheckingPermission {
                if !transcriber.hasMicrophonePermission {
                    Button(action: onRequestPermission) {
                        Label("Enable Microphone", systemImage: "mic.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if transcriber.hasAvailableAudioInputDevices() {
                    RecordingButton(
                        isRecording: transcriber.isRecording,
                        isDisabled: isDownloadingModel || transcriber.isDownloading || transcriber.isTranscribing,
                        action: onToggleRecording
                    )
                }
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}
