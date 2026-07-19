//
//  SettingsView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI
import ApplicationServices
import AppKit

// MARK: - Settings View

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
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    isRecordingShortcut = false
                    eventMonitor = nil
                }
                return nil
            }
            var modifierParts: [String] = []
            if event.modifierFlags.contains(.command) { modifierParts.append("cmd") }
            if event.modifierFlags.contains(.option) { modifierParts.append("option") }
            if event.modifierFlags.contains(.control) { modifierParts.append("control") }
            if event.modifierFlags.contains(.shift) { modifierParts.append("shift") }
            let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
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
                HStack(spacing: AppConstants.UI.spacingXS) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppConstants.UI.headerIconRadius)
                            .fill(Color.accentGradient)
                            .frame(width: AppConstants.UI.headerIconSize, height: AppConstants.UI.headerIconSize)
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(LocalizedStringKey("settings.view.title"))
                        .font(.system(size: AppConstants.UI.fontHeader, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: AppConstants.UI.iconMedium))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(LocalizedStringKey("settings.close.tooltip"))
            }
            .padding(.horizontal, AppConstants.UI.spacingMD)
            .padding(.top, AppConstants.UI.spacingSM)
            .padding(.bottom, AppConstants.UI.spacingXS)

            Divider().overlay(Color.borderPrimary)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppConstants.UI.spacingMD) {
                    // Model Selection Card
                    SettingsCard(
                        icon: "cpu",
                        iconColor: .accentPurple,
                        title: LocalizedStringKey("settings.view.model.selection.label"),
                        subtitle: LocalizedStringKey("settings.view.model.selection.subtitle")
                    ) {
                        VStack(spacing: AppConstants.UI.spacingXS) {
                            ForEach(models, id: \.0) { model, size, description in
                                ModelOptionRow(
                                    name: model.capitalized,
                                    size: size,
                                    description: NSLocalizedString(description, comment: ""),
                                    isSelected: selectedModel == model,
                                    isDownloaded: audioTranscriber.isModelAlreadyDownloaded(model: model)
                                ) {
                                    withAnimation(.spring(response: AppConstants.Animation.springResponse)) {
                                        selectedModel = model
                                    }
                                }
                            }
                        }
                    }

                    // Audio Device Card
                    SettingsCard(
                        icon: "mic",
                        iconColor: .accentPrimary,
                        title: LocalizedStringKey("settings.view.audio.input.device.label"),
                        subtitle: nil
                    ) {
                        if audioTranscriber.audioDevices.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.warningOrange)
                                Text(LocalizedStringKey("settings.view.no.audio.device.available.message"))
                                    .font(.system(size: AppConstants.UI.fontBody))
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.vertical, AppConstants.UI.spacingXS)
                        } else {
                            VStack(spacing: AppConstants.UI.spacingXXS) {
                                ForEach(0..<audioTranscriber.audioDevices.count, id: \.self) { index in
                                    DeviceOptionRow(
                                        name: audioTranscriber.audioDevices[index].name,
                                        isSelected: selectedDeviceIndex == index
                                    ) {
                                        withAnimation(.spring(response: AppConstants.Animation.springResponse)) {
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
                        iconColor: .successGreen,
                        title: LocalizedStringKey("settings.view.transcription.language.label"),
                        subtitle: nil
                    ) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppConstants.UI.spacingXS) {
                            ForEach(languages, id: \.0) { code, name in
                                LanguageOptionRow(
                                    name: name,
                                    isSelected: selectedLanguage == code
                                ) {
                                    withAnimation(.spring(response: AppConstants.Animation.springResponse)) {
                                        selectedLanguage = code
                                    }
                                }
                            }
                        }
                    }

                    // UI Language Card
                    SettingsCard(
                        icon: "textformat",
                        iconColor: .warningOrange,
                        title: LocalizedStringKey("settings.view.app.language.label"),
                        subtitle: nil
                    ) {
                        VStack(spacing: AppConstants.UI.spacingXXS) {
                            ForEach(uiLanguages, id: \.0) { code, name in
                                LanguageOptionRow(
                                    name: name,
                                    isSelected: uiLanguage == code
                                ) {
                                    withAnimation(.spring(response: AppConstants.Animation.springResponse)) {
                                        uiLanguage = code
                                    }
                                }
                            }
                        }
                    }

                    // Quick Record Shortcut Card
                    SettingsCard(
                        icon: "keyboard",
                        iconColor: .recordingRed,
                        title: LocalizedStringKey("settings.view.quick.record.shortcut.label"),
                        subtitle: LocalizedStringKey("settings.view.quick.record.shortcut.subtitle")
                    ) {
                        VStack(spacing: AppConstants.UI.spacingSM) {
                            HStack {
                                Text(LocalizedStringKey("settings.view.quick.record.shortcut.enable"))
                                    .font(.system(size: AppConstants.UI.fontBody))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Toggle("", isOn: $shortcutEnabled)
                                    .toggleStyle(SwitchToggleStyle())
                                    .labelsHidden()
                                    .tint(.accentPrimary)
                            }

                            if shortcutEnabled {
                                HStack(spacing: AppConstants.UI.spacingMD) {
                                    Button(action: { startRecordingShortcut() }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: isRecordingShortcut ? "record.circle" : "keyboard")
                                                .font(.system(size: AppConstants.UI.fontCaption))
                                            Text(isRecordingShortcut ? NSLocalizedString("settings.view.quick.record.shortcut.recording", comment: "Press your shortcut...") : NSLocalizedString("settings.view.quick.record.shortcut.record", comment: "Record Shortcut"))
                                                .font(.system(size: AppConstants.UI.fontBody))
                                        }
                                        .padding(.horizontal, AppConstants.UI.spacingSM)
                                        .padding(.vertical, 6)
                                        .background(isRecordingShortcut ? Color.recordingRed.opacity(0.15) : Color.accentPrimary.opacity(0.1))
                                        .foregroundColor(isRecordingShortcut ? .recordingRed : .accentPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(isRecordingShortcut)

                                    Spacer()
                                }

                                HStack(spacing: AppConstants.UI.spacingXXS) {
                                    Text(LocalizedStringKey("settings.view.quick.record.shortcut.current"))
                                        .font(.system(size: AppConstants.UI.fontCaption))
                                        .foregroundColor(.textSecondary)
                                    Text(currentShortcutDisplay)
                                        .font(.system(size: AppConstants.UI.fontCaption, weight: .medium))
                                        .foregroundColor(.accentPrimary)
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
                .padding(.horizontal, AppConstants.UI.spacingMD)
                .padding(.vertical, AppConstants.UI.spacingXS)
            }

            Divider().overlay(Color.borderPrimary)

            // Footer
            HStack(spacing: AppConstants.UI.spacingSM) {
                Button(action: { showResetConfirmation = true }) {
                    Label(LocalizedStringKey("settings.reset.button"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: AppConstants.UI.fontBody))
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
                        .font(.system(size: AppConstants.UI.fontBody, weight: .medium))
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, AppConstants.UI.spacingMD)
            .padding(.vertical, AppConstants.UI.spacingSM)
        }
        .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.windowHeight)
        .background(Color.bgSecondary)
        .onAppear { checkAccessibilityPermission() }
        .onChange(of: uiLanguage) { viewRefreshID = UUID() }
        .id(viewRefreshID)
    }

    private var currentShortcutDisplay: String {
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
        if !hasModifier && parts.count == 1 { return parts[0].uppercased() }
        return display.isEmpty ? "⌘V" : display
    }

    private func saveSettings() {
        UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        UserDefaults.standard.set(selectedDeviceIndex, forKey: "SelectedDeviceIndex")
        UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
        audioTranscriber.setSelectedDevice(index: selectedDeviceIndex)
        audioTranscriber.setLanguage(selectedLanguage)
        if !audioTranscriber.isModelAlreadyDownloaded(model: selectedModel) {
            NotificationCenter.default.post(name: .modelDownloadRequested, object: selectedModel)
        } else {
            NotificationCenter.default.post(name: .modelChanged, object: nil)
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
        VStack(alignment: .leading, spacing: AppConstants.UI.spacingSM) {
            HStack(spacing: AppConstants.UI.spacingXS) {
                IconContainer(
                    icon: icon,
                    color: iconColor,
                    size: AppConstants.UI.settingsIconSize,
                    radius: AppConstants.UI.radiusSM
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(titleKey)
                        .font(.system(size: AppConstants.UI.fontCardTitle, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    if let subtitleKey = subtitleKey {
                        Text(subtitleKey)
                            .font(.system(size: AppConstants.UI.fontCaption))
                            .foregroundColor(.textSecondary)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(AppConstants.UI.spacingSM)
        .cardStyle()
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
            HStack(spacing: AppConstants.UI.spacingXS) {
                RadioButton(isSelected: isSelected)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: AppConstants.UI.fontBody, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.textPrimary)
                        Badge(size, color: .textTertiary)
                        if isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: AppConstants.UI.fontCaption))
                                .foregroundColor(.successGreen)
                        }
                    }
                    Text(description)
                        .font(.system(size: AppConstants.UI.fontCaption))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, AppConstants.UI.spacingXS)
            .background(isSelected ? Color.accentPrimary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM)
                    .stroke(isSelected ? Color.accentPrimary.opacity(0.2) : Color.clear, lineWidth: 1)
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
            HStack(spacing: AppConstants.UI.spacingXS) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: AppConstants.UI.iconSmall))
                    .foregroundColor(isSelected ? .accentPrimary : .textTertiary)
                Text(name)
                    .font(.system(size: AppConstants.UI.fontBody))
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, AppConstants.UI.spacingXS)
            .background(isSelected ? Color.accentPrimary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
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
            HStack(spacing: AppConstants.UI.spacingXS) {
                Text(name)
                    .font(.system(size: AppConstants.UI.fontBody))
                    .foregroundColor(.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: AppConstants.UI.fontCaption, weight: .semibold))
                        .foregroundColor(.accentPrimary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, AppConstants.UI.spacingXS)
            .background(isSelected ? Color.accentPrimary.opacity(0.08) : Color.bgHover)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM)
                    .stroke(isSelected ? Color.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Accessibility Permission Card

struct AccessibilityPermissionCard: View {
    let onOpenSettings: () -> Void
    let onCheckAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.spacingSM) {
            HStack(spacing: AppConstants.UI.spacingXS) {
                IconContainer(
                    icon: "exclamationmark.triangle.fill",
                    color: .warningOrange,
                    size: AppConstants.UI.settingsIconSize,
                    radius: AppConstants.UI.radiusSM
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey("settings.view.accessibility.permission.label"))
                        .font(.system(size: AppConstants.UI.fontCardTitle, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text(LocalizedStringKey("settings.view.accessibility.permission.subtitle"))
                        .font(.system(size: AppConstants.UI.fontCaption))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }

            Text(LocalizedStringKey("settings.view.accessibility.permission.description"))
                .font(.system(size: AppConstants.UI.fontCaption))
                .foregroundColor(.textSecondary)
                .lineLimit(3)

            Text("1. 确保应用已在「应用程序」文件夹中\n2. 点击下方按钮打开系统设置\n3. 在列表中找到 Typeless 并开启")
                .font(.system(size: AppConstants.UI.fontCaption))
                .foregroundColor(.textSecondary)
                .lineLimit(4)

            HStack(spacing: AppConstants.UI.spacingSM) {
                Button(action: onOpenSettings) {
                    Label(LocalizedStringKey("settings.view.accessibility.permission.open.settings"), systemImage: "gear")
                        .font(.system(size: AppConstants.UI.fontCaption, weight: .medium))
                }
                .buttonStyle(SettingsPrimaryButtonStyle())

                Button(action: onCheckAgain) {
                    Label(LocalizedStringKey("settings.view.accessibility.permission.check.again"), systemImage: "arrow.clockwise")
                        .font(.system(size: AppConstants.UI.fontCaption))
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
            }
        }
        .padding(AppConstants.UI.spacingSM)
        .background(Color.warningOrange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.radiusMD)
                .stroke(Color.warningOrange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AudioTranscriber())
}
