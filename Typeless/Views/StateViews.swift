//
//  StateViews.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

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
