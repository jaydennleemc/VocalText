//
//  SettingsView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import ApplicationServices
import AppKit

struct SettingsView: View {
    @EnvironmentObject var audioTranscriber: AudioTranscriber
    @Binding var isPresented: Bool
    @State private var selectedModel = "tiny"
    @State private var selectedDeviceIndex = 0
    @State private var selectedLanguage = "zh"
    @AppStorage("selectedLanguage") private var uiLanguage: String = "en"
    @State private var showResetConfirmation = false
    @State private var viewRefreshID = UUID()
    
    // Accessibility Permission State
    @AppStorage("AccessibilityPermissionChecked") private var accessibilityPermissionChecked = false
    @State private var hasAccessibilityPermission = false
    
    // Quick Record Shortcut Settings
    @AppStorage("QuickRecordShortcutEnabled") private var shortcutEnabled = true
    @AppStorage("QuickRecordShortcut") private var shortcutString = "cmd+v"
    @State private var isRecordingShortcut = false
    @State private var eventMonitor: Any?
    
    private func startRecordingShortcut() {
        isRecordingShortcut = true
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore if holding escape to cancel
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    isRecordingShortcut = false
                    eventMonitor = nil
                }
                return nil
            }
            
            // Build shortcut string from modifiers and key
            var modifierParts: [String] = []
            if event.modifierFlags.contains(.command) { modifierParts.append("cmd") }
            if event.modifierFlags.contains(.option) { modifierParts.append("option") }
            if event.modifierFlags.contains(.control) { modifierParts.append("control") }
            if event.modifierFlags.contains(.shift) { modifierParts.append("shift") }
            
            // Get the key character
            let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
            
            // Require at least one modifier + a valid key
            if !modifierParts.isEmpty && !keyChar.isEmpty {
                modifierParts.append(keyChar)
                let shortcut = modifierParts.joined(separator: "+")
                
                DispatchQueue.main.async {
                    shortcutString = shortcut
                    isRecordingShortcut = false
                    eventMonitor = nil
                }
            }
            
            return nil
        }
    }
    
    private func openAccessibilitySettings() {
        // 先尝试触发系统权限对话框
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            // 如果对话框没显示，直接打开系统设置
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        accessibilityPermissionChecked = true
    }

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
                    
                    // Quick Record Shortcut Card
                    SettingsCard(
                        icon: "keyboard",
                        iconColor: .red,
                        title: LocalizedStringKey("settings.view.quick.record.shortcut.label"),
                        subtitle: LocalizedStringKey("settings.view.quick.record.shortcut.subtitle")
                    ) {
                        VStack(spacing: 12) {
                            HStack {
                                Text(LocalizedStringKey("settings.view.quick.record.shortcut.enable"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Spacer()
                                Toggle("", isOn: $shortcutEnabled)
                                    .toggleStyle(SwitchToggleStyle())
                                    .labelsHidden()
                            }
                            
                            if shortcutEnabled {
                                HStack(spacing: 16) {
                                    Button(action: {
                                        startRecordingShortcut()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: isRecordingShortcut ? "record.circle" : "keyboard")
                                                .font(.system(size: 12))
                                            Text(isRecordingShortcut ? NSLocalizedString("settings.view.quick.record.shortcut.recording", comment: "Press your shortcut...") : NSLocalizedString("settings.view.quick.record.shortcut.record", comment: "Record Shortcut"))
                                                .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isRecordingShortcut ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.1))
                                        .foregroundColor(isRecordingShortcut ? .red : .accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(isRecordingShortcut)
                                    
                                    Spacer()
                                }
                                
                                HStack(spacing: 4) {
                                    Text(LocalizedStringKey("settings.view.quick.record.shortcut.current"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(currentShortcutDisplay)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    
                    // Accessibility Permission Warning
                    if !hasAccessibilityPermission {
                        AccessibilityPermissionCard(
                            onOpenSettings: openAccessibilitySettings,
                            onCheckAgain: checkAccessibilityPermission
                        )
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
        .onAppear {
            checkAccessibilityPermission()
        }
        .onChange(of: uiLanguage) {
            viewRefreshID = UUID()
        }
        .id(viewRefreshID)
    }
    
    private var currentShortcutDisplay: String {
        // Parse shortcutString like "cmd+shift+v" and display as "⌘⇧V"
        let parts = shortcutString.lowercased().components(separatedBy: "+")
        var display = ""
        var hasModifier = false
        
        for part in parts {
            switch part {
            case "cmd": display += "⌘"; hasModifier = true
            case "option", "opt": display += "⌥"; hasModifier = true
            case "control", "ctrl": display += "⌃"; hasModifier = true
            case "shift": display += "⇧"; hasModifier = true
            default: display += part.uppercased()
            }
        }
        
        // If no modifiers, just show the key
        if !hasModifier && parts.count == 1 {
            return parts[0].uppercased()
        }
        
        return display.isEmpty ? "⌘V" : display
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

struct AccessibilityPermissionCard: View {
    let onOpenSettings: () -> Void
    let onCheckAgain: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 28, height: 28)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey("settings.view.accessibility.permission.label"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(LocalizedStringKey("settings.view.accessibility.permission.subtitle"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(LocalizedStringKey("settings.view.accessibility.permission.description"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Text("1. 确保应用已在「应用程序」文件夹中\n2. 点击下方按钮打开系统设置\n3. 在列表中找到 Typeless 并开启")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(4)
            
            HStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    Label(LocalizedStringKey("settings.view.accessibility.permission.open.settings"), systemImage: "gear")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                
                Button(action: onCheckAgain) {
                    Label(LocalizedStringKey("settings.view.accessibility.permission.check.again"), systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
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
