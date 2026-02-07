//
//  SettingsView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioTranscriber: AudioTranscriber
    @Binding var isPresented: Bool
    @State private var selectedModel = "tiny"
    @State private var selectedDeviceIndex = 0
    @State private var selectedLanguage = "zh"
    @AppStorage("selectedLanguage") private var uiLanguage: String = "en"
    @State private var showResetConfirmation = false
    @State private var viewRefreshID = UUID()

    let models = [
        ("tiny", "~75MB", "settings.model.tiny.description"),
        ("base", "~150MB", "settings.model.base.description"),
        ("small", "~480MB", "settings.model.small.description"),
        ("medium", "~1.5GB", "settings.model.medium.description"),
        ("large-v3", "~3GB", "settings.model.large.description")
    ]
    
    var languages: [(String, String)] {
        [
            ("zh", NSLocalizedString("language.zh", comment: "Chinese")),
            ("en", NSLocalizedString("language.en", comment: "English")),
            ("ja", NSLocalizedString("language.ja", comment: "Japanese")),
            ("ko", NSLocalizedString("language.ko", comment: "Korean")),
            ("fr", NSLocalizedString("language.fr", comment: "French")),
            ("de", NSLocalizedString("language.de", comment: "German")),
            ("es", NSLocalizedString("language.es", comment: "Spanish"))
        ]
    }
    
    var uiLanguages: [(String, String)] {
        [
            ("en", NSLocalizedString("ui.language.en", comment: "English UI")),
            ("zh-Hans", NSLocalizedString("ui.language.zh-Hans", comment: "Simplified Chinese UI")),
            ("zh-Hant", NSLocalizedString("ui.language.zh-Hant", comment: "Traditional Chinese UI"))
        ]
    }
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        
        if let savedModel = UserDefaults.standard.string(forKey: "SelectedModel") {
            self._selectedModel = State(initialValue: savedModel)
        }
        
        self._selectedDeviceIndex = State(initialValue: UserDefaults.standard.integer(forKey: "SelectedDeviceIndex"))
        
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            self._selectedLanguage = State(initialValue: savedLanguage)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    
                    Text(LocalizedStringKey("settings.view.title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help(LocalizedStringKey("settings.close.tooltip"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Model Selection Card
                    SettingsCard(
                        icon: "cpu",
                        iconColor: .purple,
                        title: LocalizedStringKey("settings.view.model.selection.label"),
                        subtitle: LocalizedStringKey("settings.view.model.selection.subtitle")
                    ) {
                        VStack(spacing: 8) {
                            ForEach(models, id: \.0) { model, size, description in
                                ModelOptionRow(
                                    name: model.capitalized,
                                    size: size,
                                    description: NSLocalizedString(description, comment: ""),
                                    isSelected: selectedModel == model,
                                    isDownloaded: audioTranscriber.isModelAlreadyDownloaded(model: model)
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedModel = model
                                    }
                                }
                            }
                        }
                    }
                    
                    // Audio Device Card
                    SettingsCard(
                        icon: "mic",
                        iconColor: .blue,
                        title: LocalizedStringKey("settings.view.audio.input.device.label"),
                        subtitle: nil
                    ) {
                        if audioTranscriber.audioDevices.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("settings.view.no.audio.device.available.message"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(0..<audioTranscriber.audioDevices.count, id: \.self) { index in
                                    DeviceOptionRow(
                                        name: audioTranscriber.audioDevices[index].name,
                                        isSelected: selectedDeviceIndex == index
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedDeviceIndex = index
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Transcription Language Card
                    SettingsCard(
                        icon: "globe",
                        iconColor: .green,
                        title: LocalizedStringKey("settings.view.transcription.language.label"),
                        subtitle: nil
                    ) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(languages, id: \.0) { code, name in
                                LanguageOptionRow(
                                    name: name,
                                    isSelected: selectedLanguage == code
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedLanguage = code
                                    }
                                }
                            }
                        }
                    }
                    
                    // UI Language Card
                    SettingsCard(
                        icon: "textformat",
                        iconColor: .orange,
                        title: LocalizedStringKey("settings.view.app.language.label"),
                        subtitle: nil
                    ) {
                        VStack(spacing: 4) {
                            ForEach(uiLanguages, id: \.0) { code, name in
                                LanguageOptionRow(
                                    name: name,
                                    isSelected: uiLanguage == code
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        uiLanguage = code
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Button(action: { showResetConfirmation = true }) {
                    Label(LocalizedStringKey("settings.reset.button"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .help(LocalizedStringKey("settings.reset.tooltip"))
                .alert(isPresented: $showResetConfirmation) {
                    Alert(
                        title: Text(LocalizedStringKey("settings.reset.confirmation.title")),
                        message: Text(LocalizedStringKey("settings.reset.confirmation.message")),
                        primaryButton: .destructive(Text(LocalizedStringKey("settings.reset.confirmation.reset"))) {
                            resetSettings()
                        },
                        secondaryButton: .cancel(Text(LocalizedStringKey("general.cancel.button")))
                    )
                }
                
                Spacer()
                
                Button(action: saveSettings) {
                    Label(LocalizedStringKey("general.save.button"), systemImage: "checkmark")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 300)
        .onChange(of: uiLanguage) {
            viewRefreshID = UUID()
        }
        .id(viewRefreshID)
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        UserDefaults.standard.set(selectedDeviceIndex, forKey: "SelectedDeviceIndex")
        UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
        
        audioTranscriber.setSelectedDevice(index: selectedDeviceIndex)
        audioTranscriber.setLanguage(selectedLanguage)
        
        if !audioTranscriber.isModelAlreadyDownloaded(model: selectedModel) {
            NotificationCenter.default.post(name: Notification.Name("ModelDownloadRequested"), object: selectedModel)
        } else {
            NotificationCenter.default.post(name: Notification.Name("ModelChanged"), object: nil)
        }
        
        isPresented = false
    }
    
    private func resetSettings() {
        selectedModel = "tiny"
        selectedDeviceIndex = 0
        selectedLanguage = "zh"
        uiLanguage = "en"
        
        UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        UserDefaults.standard.set(selectedDeviceIndex, forKey: "SelectedDeviceIndex")
        UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
        UserDefaults.standard.set(uiLanguage, forKey: "selectedLanguage")
        
        audioTranscriber.setSelectedDevice(index: selectedDeviceIndex)
        audioTranscriber.setLanguage(selectedLanguage)
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey?
    let content: Content
    
    init(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey?,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.titleKey = title
        self.subtitleKey = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(titleKey)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let subtitleKey = subtitleKey {
                        Text(subtitleKey)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            content
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Model Option Row

struct ModelOptionRow: View {
    let name: String
    let size: String
    let description: String
    let isSelected: Bool
    let isDownloaded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.primary)
                        
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        if isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Device Option Row

struct DeviceOptionRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Language Option Row

struct LanguageOptionRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .foregroundColor(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AudioTranscriber())
}
