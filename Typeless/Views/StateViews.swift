//
//  StateViews.swift
//  Typeless
//

import SwiftUI

// MARK: - Generic placeholder

struct StatusPlaceholder: View {
    let symbol: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Loading

struct LoadingStateView: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)

            VStack(spacing: 4) {
                Text(titleKey)
                    .font(.system(size: 14, weight: .medium))
                if let subtitleKey {
                    Text(subtitleKey)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Download

struct DownloadProgressView: View {
    let status: String
    let progress: Double

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 10) {
                Text(status)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(width: 220)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Processing

struct ProcessingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.accentColor)

            Text("Processing transcription…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording

struct RecordingStateView: View {
    let volumeLevel: Double
    let recordingTime: TimeInterval

    var body: some View {
        VStack(spacing: 18) {
            VoiceMemoWaveformView(volumeLevel: volumeLevel)
                .frame(height: 72)
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)

                Text(formatTime(recordingTime))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Text("Click the button to stop")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let cs = Int((t.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}

// MARK: - Permission

struct PermissionRequiredView: View {
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("Microphone access needed")
                    .font(.system(size: 14, weight: .semibold))
                Text("Grant microphone access in System Settings to transcribe speech on-device.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: onRequestPermission) {
                Label("Enable Microphone", systemImage: "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - No device

struct NoAudioDeviceView: View {
    var body: some View {
        StatusPlaceholder(
            symbol: "speaker.slash.circle.fill",
            title: "No audio input",
            subtitle: "Connect a microphone or check Sound settings."
        )
    }
}
