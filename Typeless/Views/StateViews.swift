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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

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
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
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
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(descriptionKey)
                .font(.system(size: 11))
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
                .tint(.accentColor)

            VStack(spacing: 4) {
                Text(titleKey)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                if let subtitleKey = subtitleKey {
                    Text(subtitleKey)
                        .font(.system(size: 13))
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
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text(status)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.accentColor)
                    .frame(width: 200)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .medium))
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
                    .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 3)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(LinearGradient(colors: [.accentColor, .purple], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }

            Text("Processing transcription...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording State View

struct RecordingStateView: View {
    let volumeLevel: Double
    let recordingTime: TimeInterval

    var body: some View {
        VStack(spacing: 20) {
            VoiceMemoWaveformView(volumeLevel: volumeLevel)
                .frame(height: 80)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)

                Text(formatTime(recordingTime))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Text("Click to stop recording")
                .font(.system(size: 13))
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
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Microphone Permission Needed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Please grant microphone access in System Settings to use voice transcription.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: onRequestPermission) {
                Label("Enable Microphone", systemImage: "mic.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
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
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Audio Input Device Detected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Please connect a microphone or check your audio settings.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}