import Foundation
import AVFoundation
import AppKit

// MARK: - Permission Manager

@MainActor
final class PermissionManager: ObservableObject {
    @Published var hasMicrophonePermission = false
    @Published var isCheckingPermission = true
    @Published var hasRequestedPermission = false

    // MARK: - Microphone Permission

    func checkMicrophonePermission() {
        if hasRequestedPermission {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasMicrophonePermission = granted
                    self?.isCheckingPermission = false
                }
            }
            return
        }

        isCheckingPermission = true

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.hasMicrophonePermission = granted
                self?.isCheckingPermission = false
                self?.hasRequestedPermission = true
            }
        }
    }

    func requestMicrophonePermission() {
        if hasRequestedPermission {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasMicrophonePermission = granted
                    self?.isCheckingPermission = false

                    if !granted {
                        self?.showMicrophoneSettingsAlert()
                    }
                }
            }
            return
        }

        isCheckingPermission = true
        hasRequestedPermission = true

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.hasMicrophonePermission = granted
                self?.isCheckingPermission = false

                if !granted {
                    self?.showMicrophoneSettingsAlert()
                }
            }
        }
    }

    private func showMicrophoneSettingsAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("main.view.microphone.permission.needed.alert.title", comment: "")
        alert.informativeText = NSLocalizedString("main.view.microphone.permission.needed.alert.message", comment: "")
        alert.addButton(withTitle: NSLocalizedString("main.view.open.settings.button", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("general.cancel.button", comment: ""))

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
}