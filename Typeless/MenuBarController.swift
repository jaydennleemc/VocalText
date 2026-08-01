//
//  MenuBarController.swift
//  Typeless
//

import Cocoa
import SwiftUI
import Combine

/// IME-style shell: menu bar status item + hold-to-talk overlay.
/// Configuration lives in the Settings window, not a mini-app popover.
@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var keyboardShortcutManager: KeyboardShortcutManager!
    private lazy var overlayManager = TranscriptionOverlayManager()

    override init() {
        super.init()
        setupMenuBar()
        keyboardShortcutManager = KeyboardShortcutManager(menuBarController: self)
        keyboardShortcutManager.setupAppMenuShortcuts()
        bootstrapEngine()
        observeStatusIcon()
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Typeless")
            button.image?.isTemplate = true
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let t = AudioTranscriber.shared

        let statusTitle: String
        if t.isModelReady {
            statusTitle = "Ready · \(t.modelManager.modelName)"
        } else if let err = t.modelManager.lastLoadError, !err.isEmpty {
            statusTitle = "Load failed · \(err.prefix(48))"
        } else {
            statusTitle = t.bootStatus
        }
        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if !t.isModelReady {
            let retry = NSMenuItem(
                title: "Retry Load Model",
                action: #selector(retryLoadModel),
                keyEquivalent: ""
            )
            retry.target = self
            menu.addItem(retry)
        }

        let hint = NSMenuItem(
            title: shortcutHintTitle(),
            action: nil,
            keyEquivalent: ""
        )
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        // Manual dictate (works even if hotkey fails — for diagnosis)
        let dictating = t.isRecording || t.isQuickRecording
        let dictate = NSMenuItem(
            title: dictating ? "Stop Dictating" : "Start Dictating",
            action: #selector(toggleDictateFromMenu),
            keyEquivalent: ""
        )
        dictate.target = self
        // Always allow — ensureWhisperKit runs on stop if still loading.
        dictate.isEnabled = true
        menu.addItem(dictate)
        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: NSLocalizedString("settings.view.title", comment: "Settings") + "…",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let history = NSMenuItem(
            title: "History",
            action: #selector(openHistory),
            keyEquivalent: "y"
        )
        history.keyEquivalentModifierMask = [.command]
        history.target = self
        menu.addItem(history)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: NSLocalizedString("general.quit.button", comment: ""),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func shortcutHintTitle() -> String {
        let key = UserDefaults.standard.string(forKey: "QuickRecordShortcutKey") ?? "cmd+shift+d"
        return "Hold \(ShortcutFormatting.display(key)) · or use menu"
    }

    private func observeStatusIcon() {
        let t = AudioTranscriber.shared

        // Throttle icon updates — rapid rebuildMenu froze the status item.
        Publishers.CombineLatest3(t.$isRecording, t.$isTranscribing, t.$isModelReady)
            .combineLatest(t.$isDownloading)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] state, downloading in
                let (recording, transcribing, ready) = state
                self?.updateStatusIcon(
                    recording: recording,
                    transcribing: transcribing,
                    ready: ready,
                    downloading: downloading
                )
            }
            .store(in: &cancellables)

        // Rebuild labels when dictate session flips (hotkey or menu).
        Publishers.CombineLatest(t.$isRecording, t.$isQuickRecording)
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        t.$isModelReady
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        t.$bootStatus
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.statusItem.button?.toolTip = status
            }
            .store(in: &cancellables)

        t.$lastErrorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.statusItem.button?.toolTip = message
            }
            .store(in: &cancellables)

        // Keep keyboard session flags in sync when a session ends without
        // going through menu/Carbon end (e.g. start failed → finishQuickSession).
        t.$isQuickRecording
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                if !active {
                    self?.keyboardShortcutManager.endSession()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func updateStatusIcon(recording: Bool, transcribing: Bool, ready: Bool, downloading: Bool) {
        let name: String
        if recording {
            name = "waveform.badge.mic"
        } else if transcribing {
            name = "ellipsis.circle"
        } else if downloading {
            name = "arrow.down.circle"
        } else if !ready {
            name = "hourglass"
        } else {
            name = "waveform"
        }
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Typeless")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = AudioTranscriber.shared.bootStatus
    }

    // MARK: - Bootstrap

    private func bootstrapEngine() {
        let t = AudioTranscriber.shared
        // Lightweight sync work only — keep menu bar responsive.
        t.checkMicrophonePermission()
        t.getAvailableAudioDevices()

        if let model = UserDefaults.standard.string(forKey: "SelectedModel") {
            t.setModel(model) // also migrates tiny/base → medium
        } else {
            t.setModel("medium")
        }
        if let language = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            t.setLanguage(language)
        }

        // Auto download (if needed) + load Core ML into memory so first dictate is fast.
        Task(priority: .userInitiated) {
            await t.prepareModelAtLaunch()
            #if DEBUG
            print("🚀 Boot complete: ready=\(t.isModelReady) status=\(t.bootStatus)")
            #endif
        }
    }

    // MARK: - Actions

    @objc func openSettingsAction() {
        AppWindows.openSettings()
    }

    @objc private func retryLoadModel() {
        Task {
            await AudioTranscriber.shared.prepareModelAtLaunch()
            rebuildMenu()
        }
    }

    @objc func openHistory() {
        AppWindows.openHistory()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Menu fallback when global hotkey is broken (no Accessibility / sandbox).
    /// Toggle session — same audio path as hold, without hold-poll.
    @objc private func toggleDictateFromMenu() {
        let t = AudioTranscriber.shared
        let active = t.isRecording || t.isQuickRecording || keyboardShortcutManager.isQuickRecordInProgress
        if active {
            keyboardShortcutManager.endSession()
            stopQuickRecord()
        } else {
            keyboardShortcutManager.beginMenuSession()
            startQuickRecord()
        }
        rebuildMenu()
    }

    func startQuickRecord() {
        applySavedModelAndLanguage()
        AudioTranscriber.shared.beginQuickRecord()
        overlayManager.showOverlay(transcriber: AudioTranscriber.shared)
    }

    func stopQuickRecord() {
        AudioTranscriber.shared.endQuickRecord()
    }

    private func applySavedModelAndLanguage() {
        let t = AudioTranscriber.shared
        if let model = UserDefaults.standard.string(forKey: "SelectedModel") {
            t.setModel(model)
        }
        if let language = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            t.setLanguage(language)
        }
    }

    deinit {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
