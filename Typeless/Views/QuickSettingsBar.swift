//
//  QuickSettingsBar.swift
//  Typeless
//

import SwiftUI

/// Compact model / language / device menus for the main popover.
struct QuickSettingsBar: View {
    @ObservedObject var transcriber: AudioTranscriber
    @Binding var selectedModel: String
    var onOpenAllSettings: () -> Void

    private let models = ["small", "medium", "large-v3"]

    private var languages: [(code: String, name: String)] {
        [
            ("zh", NSLocalizedString("language.zh", comment: "Chinese")),
            ("yue", NSLocalizedString("language.yue", comment: "Cantonese")),
            ("en", NSLocalizedString("language.en", comment: "English")),
            ("ja", NSLocalizedString("language.ja", comment: "Japanese")),
            ("ko", NSLocalizedString("language.ko", comment: "Korean")),
            ("fr", NSLocalizedString("language.fr", comment: "French")),
            ("de", NSLocalizedString("language.de", comment: "German")),
            ("es", NSLocalizedString("language.es", comment: "Spanish")),
        ]
    }

    @State private var selectedLanguage: String =
        UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "zh"

    private var isBusy: Bool {
        transcriber.isRecording || transcriber.isTranscribing || transcriber.isDownloading
    }

    var body: some View {
        HStack(spacing: 6) {
            modelMenu
            languageMenu
            deviceMenu

            Spacer(minLength: 4)

            Button(action: onOpenAllSettings) {
                Text("All Settings…")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(isBusy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .opacity(isBusy ? 0.45 : 1)
        .disabled(isBusy)
    }

    private var modelMenu: some View {
        Menu {
            ForEach(models, id: \.self) { model in
                Button {
                    selectedModel = model.capitalized
                    UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
                    transcriber.setModel(model)
                    if !transcriber.isModelAlreadyDownloaded(model: model) {
                        Task {
                            _ = await transcriber.checkAndDownloadModelIfNeeded()
                            await transcriber.preloadWhisperKit()
                        }
                    } else {
                        Task { await transcriber.preloadWhisperKit() }
                    }
                } label: {
                    HStack {
                        Text(model.capitalized)
                        if selectedModel.lowercased() == model {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            chipLabel(systemImage: "cpu", text: selectedModel.capitalized)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Model")
    }

    private var languageMenu: some View {
        Menu {
            ForEach(languages, id: \.code) { item in
                Button {
                    selectedLanguage = item.code
                    UserDefaults.standard.set(item.code, forKey: "SelectedLanguage")
                    transcriber.setLanguage(item.code)
                } label: {
                    HStack {
                        Text(item.name)
                        if selectedLanguage == item.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            let name = languages.first(where: { $0.code == selectedLanguage })?.name ?? selectedLanguage
            chipLabel(systemImage: "globe", text: name)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Language")
    }

    private var deviceMenu: some View {
        Menu {
            if transcriber.audioDevices.isEmpty {
                Text("No devices")
            } else {
                ForEach(Array(transcriber.audioDevices.enumerated()), id: \.element.id) { index, device in
                    Button {
                        transcriber.setSelectedDevice(index: index)
                    } label: {
                        HStack {
                            Text(device.name)
                            if index == transcriber.selectedDeviceIndex {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            let name = transcriber.audioDevices.indices.contains(transcriber.selectedDeviceIndex)
                ? transcriber.audioDevices[transcriber.selectedDeviceIndex].name
                : "Device"
            chipLabel(systemImage: "mic", text: shortDeviceName(name))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Input device")
    }

    private func chipLabel(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.4), in: Capsule())
    }

    private func shortDeviceName(_ name: String) -> String {
        if name.count <= 16 { return name }
        return String(name.prefix(14)) + "…"
    }
}
