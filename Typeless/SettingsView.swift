//
//  SettingsView.swift
//  Typeless
//
//  Compact macOS Settings–style UI.
//  Pages: Dictation · Model · General
//

import SwiftUI
import AppKit

// MARK: - Sidebar

private enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general, model, dictation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .model: return "Model"
        case .dictation: return "Dictation"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .model: return "cpu"
        case .dictation: return "waveform"
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var audioTranscriber: AudioTranscriber

    @State private var page: SettingsPage = .general
    @State private var selectedModel = "medium"
    @State private var selectedDeviceIndex = 0
    @State private var selectedLanguage = "zh"
    @AppStorage("selectedLanguage") private var uiLanguage: String = "en"
    @AppStorage("QuickRecordShortcutEnabled") private var shortcutEnabled = true
    @AppStorage("QuickRecordShortcutKey") private var shortcutString = "cmd+shift+d"
    @State private var isRecordingShortcut = false
    @State private var eventMonitor: Any?
    @State private var hasAccessibilityPermission = AccessibilityAuth.isTrusted
    @State private var showResetConfirmation = false
    @State private var didCopyPath = false

    private let models: [(id: String, size: String, detailKey: String)] = [
        ("small", "~480 MB", "settings.model.small.description"),
        ("medium", "~1.5 GB", "settings.model.medium.description"),
        ("large-v3", "~3 GB", "settings.model.large.description"),
    ]

    private let allowedModels: Set<String> = ["small", "medium", "large-v3"]

    private var languages: [(id: String, name: String)] {
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

    private var uiLanguages: [(id: String, name: String)] {
        [
            ("en", NSLocalizedString("ui.language.en", comment: "")),
            ("zh-Hans", NSLocalizedString("ui.language.zh-Hans", comment: "")),
            ("zh-Hant", NSLocalizedString("ui.language.zh-Hant", comment: "")),
        ]
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "SelectedModel")?.lowercased() ?? "medium"
        let model = ["small", "medium", "large-v3"].contains(raw) ? raw : "medium"
        _selectedModel = State(initialValue: model)
        _selectedDeviceIndex = State(initialValue: UserDefaults.standard.integer(forKey: "SelectedDeviceIndex"))
        if let l = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            _selectedLanguage = State(initialValue: l)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsPage.allCases) { item in
                    sidebarButton(item)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(width: 128)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Group {
                switch page {
                case .general: generalPage
                case .model: modelPage
                case .dictation: dictationPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 520, height: 400)
        .onAppear {
            // Persist clamp if UserDefaults still holds a retired model name.
            if let saved = UserDefaults.standard.string(forKey: "SelectedModel")?.lowercased(),
               !allowedModels.contains(saved) {
                applyModel("medium")
            }
            checkAccessibilityPermission()
            audioTranscriber.getAvailableAudioDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityTrustChanged)) { note in
            if let trusted = note.object as? Bool {
                hasAccessibilityPermission = trusted
            } else {
                checkAccessibilityPermission()
            }
        }
        .onChange(of: selectedModel) { applyModel($0) }
        .onChange(of: selectedLanguage) { applyLanguage($0) }
        .onChange(of: selectedDeviceIndex) { applyDevice($0) }
        .alert(
            NSLocalizedString("settings.reset.confirmation.title", comment: ""),
            isPresented: $showResetConfirmation
        ) {
            Button(NSLocalizedString("settings.reset.confirmation.reset", comment: ""), role: .destructive) {
                resetSettings()
            }
            Button(NSLocalizedString("general.cancel.button", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("settings.reset.confirmation.message", comment: ""))
        }
    }

    private func sidebarButton(_ item: SettingsPage) -> some View {
        Button {
            page = item
        } label: {
            Label(item.title, systemImage: item.symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12, weight: page == item ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    page == item
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .foregroundStyle(page == item ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dictation

    private var dictationPage: some View {
        Form {
            Section {
                Text("Hold \(shortcutDisplay) · speak · release. Menu → Start Dictating also works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Shortcut") {
                Toggle("Enable Shortcut", isOn: $shortcutEnabled)
                    .controlSize(.small)

                if shortcutEnabled {
                    LabeledContent("Keys") {
                        HStack(spacing: 6) {
                            Text(shortcutDisplay)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

                            Button(isRecordingShortcut ? "…" : "Change") {
                                startRecordingShortcut()
                            }
                            .controlSize(.small)
                            .disabled(isRecordingShortcut)
                        }
                    }
                }
            }

            Section("Input") {
                Picker("Speech", selection: $selectedLanguage) {
                    ForEach(languages, id: \.id) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .controlSize(.small)

                if audioTranscriber.audioDevices.isEmpty {
                    Text(NSLocalizedString("settings.view.no.audio.device.available.message", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Mic", selection: $selectedDeviceIndex) {
                        ForEach(Array(audioTranscriber.audioDevices.enumerated()), id: \.element.id) { index, device in
                            Text(device.name).tag(index)
                        }
                    }
                    .controlSize(.small)
                }

                Button("Refresh Mics") {
                    audioTranscriber.getAvailableAudioDevices()
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .padding(8)
    }

    // MARK: - Model

    private var modelPage: some View {
        Form {
            Section {
                Picker("Model", selection: $selectedModel) {
                    ForEach(models, id: \.id) { model in
                        HStack {
                            Text(model.id)
                            Spacer(minLength: 6)
                            Text(model.size)
                                .foregroundStyle(.secondary)
                            if audioTranscriber.isModelAlreadyDownloaded(model: model.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.green)
                                    .imageScale(.small)
                            }
                        }
                        .tag(model.id)
                    }
                }
                .pickerStyle(.radioGroup)
                .controlSize(.small)
            } footer: {
                if let detail = models.first(where: { $0.id == selectedModel }) {
                    Text(NSLocalizedString(detail.detailKey, comment: ""))
                        .font(.caption)
                }
            }

            if audioTranscriber.isDownloading {
                Section {
                    ProgressView(value: audioTranscriber.downloadProgress) {
                        Text(audioTranscriber.bootStatus)
                            .font(.caption2)
                    }
                    .controlSize(.small)
                }
            } else if !audioTranscriber.isModelAlreadyDownloaded(model: selectedModel) {
                Section {
                    Button("Download Model") {
                        applyModel(selectedModel)
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .padding(8)
    }

    // MARK: - General

    private var generalPage: some View {
        Form {
            Section("Interface") {
                Picker("Language", selection: $uiLanguage) {
                    ForEach(uiLanguages, id: \.id) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .controlSize(.small)
            }

            Section {
                LabeledContent("Accessibility") {
                    HStack(spacing: 4) {
                        Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(hasAccessibilityPermission ? Color.green : Color.orange)
                            .imageScale(.small)
                        Text(hasAccessibilityPermission ? "On" : "Off")
                            .font(.caption)
                            .foregroundStyle(hasAccessibilityPermission ? Color.secondary : Color.orange)
                    }
                }

                if !hasAccessibilityPermission {
                    Text("Needed for global shortcut & paste into other apps.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if AccessibilityAuth.isRunningFromXcodeDerivedData {
                        Text("Xcode build: enable this DerivedData app, not only /Applications.")
                            .font(.caption2)
                            .foregroundStyle(Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(AccessibilityAuth.processPathHint)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Button("System Settings") { AccessibilityAuth.requestAccess() }
                        Button(didCopyPath ? "Copied" : "Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(AccessibilityAuth.processPathHint, forType: .string)
                            didCopyPath = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyPath = false }
                        }
                        Button("Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: AccessibilityAuth.processPathHint)
                            ])
                        }
                        Button("Recheck") { checkAccessibilityPermission() }
                    }
                    .controlSize(.mini)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("On-device transcription only.")
                    .font(.caption2)
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.caption)
                }
                Link("WhisperKit", destination: URL(string: "https://github.com/argmaxinc/WhisperKit")!)
                    .font(.caption)
            }

            Section {
                Button("Reset Settings…", role: .destructive) {
                    showResetConfirmation = true
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .padding(8)
    }

    // MARK: - Helpers

    private var shortcutDisplay: String {
        ShortcutFormatting.display(shortcutString)
    }

    private func startRecordingShortcut() {
        isRecordingShortcut = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    isRecordingShortcut = false
                    if let mon = eventMonitor { NSEvent.removeMonitor(mon) }
                    eventMonitor = nil
                }
                return nil
            }
            var mods: [String] = []
            if event.modifierFlags.contains(.command) { mods.append("cmd") }
            if event.modifierFlags.contains(.option) { mods.append("option") }
            if event.modifierFlags.contains(.control) { mods.append("control") }
            if event.modifierFlags.contains(.shift) { mods.append("shift") }
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if !mods.isEmpty, !key.isEmpty {
                let shortcut = (mods + [String(key.prefix(1))]).joined(separator: "+")
                DispatchQueue.main.async {
                    shortcutString = shortcut
                    isRecordingShortcut = false
                    if let mon = eventMonitor { NSEvent.removeMonitor(mon) }
                    eventMonitor = nil
                }
            }
            return nil
        }
    }

    private func applyModel(_ model: String) {
        var m = model.lowercased()
        if !allowedModels.contains(m) { m = "medium" }
        UserDefaults.standard.set(m, forKey: "SelectedModel")
        audioTranscriber.setModel(m)
        Task {
            if !audioTranscriber.isModelAlreadyDownloaded(model: m) {
                _ = await audioTranscriber.checkAndDownloadModelIfNeeded()
            }
            await audioTranscriber.preloadWhisperKit()
        }
    }

    private func applyLanguage(_ code: String) {
        UserDefaults.standard.set(code, forKey: "SelectedLanguage")
        audioTranscriber.setLanguage(code)
    }

    private func applyDevice(_ index: Int) {
        UserDefaults.standard.set(index, forKey: "SelectedDeviceIndex")
        audioTranscriber.setSelectedDevice(index: index)
    }

    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AccessibilityAuth.isTrusted
    }

    private func resetSettings() {
        selectedModel = "medium"
        selectedDeviceIndex = 0
        selectedLanguage = "zh"
        uiLanguage = "en"
        shortcutEnabled = true
        shortcutString = "cmd+shift+d"
        UserDefaults.standard.set("medium", forKey: "SelectedModel")
        UserDefaults.standard.set(0, forKey: "SelectedDeviceIndex")
        UserDefaults.standard.set("zh", forKey: "SelectedLanguage")
        applyModel("medium")
        applyLanguage("zh")
        applyDevice(0)
    }
}

// MARK: - Shared shortcut display

enum ShortcutFormatting {
    static func display(_ shortcut: String) -> String {
        let parts = shortcut.lowercased().components(separatedBy: "+")
        var display = ""
        for part in parts {
            switch part {
            case "cmd", "command": display += "⌘"
            case "option", "opt": display += "⌥"
            case "control", "ctrl": display += "⌃"
            case "shift": display += "⇧"
            default: display += part.uppercased()
            }
        }
        return display.isEmpty ? "⌘⇧D" : display
    }
}

#Preview {
    SettingsView()
        .environmentObject(AudioTranscriber.shared)
}
