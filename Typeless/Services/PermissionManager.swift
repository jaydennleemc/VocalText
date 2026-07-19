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
        requestPermission(showAlertOnDeny: false)
    }

    func requestMicrophonePermission() {
        requestPermission(showAlertOnDeny: true)
    }

    private func requestPermission(showAlertOnDeny: Bool) {
        if !hasRequestedPermission {
            isCheckingPermission = true
            hasRequestedPermission = true
        }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.hasMicrophonePermission = granted
                self.isCheckingPermission = false
                if !granted && showAlertOnDeny {
                    self.showMicrophoneSettingsAlert()
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