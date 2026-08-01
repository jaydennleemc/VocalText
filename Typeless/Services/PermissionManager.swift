import Foundation
import AVFoundation
import AppKit

// MARK: - Permission Manager

@MainActor
final class PermissionManager: ObservableObject {
    @Published var hasMicrophonePermission = false
    @Published var isCheckingPermission = true
    @Published var hasRequestedPermission = false

    init() {
        // Synchronous snapshot so we don't block recording waiting on async prompt state.
        refreshStatus()
    }

    func refreshStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        hasMicrophonePermission = (status == .authorized)
        isCheckingPermission = (status == .notDetermined)
    }

    func checkMicrophonePermission() {
        refreshStatus()
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            requestPermission(showAlertOnDeny: false)
        }
    }

    func requestMicrophonePermission() {
        requestPermission(showAlertOnDeny: true)
    }

    /// Awaitable grant for dictate start path.
    func ensurePermission() async -> Bool {
        refreshStatus()
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            hasMicrophonePermission = true
            isCheckingPermission = false
            return true
        case .denied, .restricted:
            hasMicrophonePermission = false
            isCheckingPermission = false
            showMicrophoneSettingsAlert()
            return false
        case .notDetermined:
            hasRequestedPermission = true
            isCheckingPermission = true
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    cont.resume(returning: ok)
                }
            }
            hasMicrophonePermission = granted
            isCheckingPermission = false
            if !granted { showMicrophoneSettingsAlert() }
            return granted
        @unknown default:
            return false
        }
    }

    private func requestPermission(showAlertOnDeny: Bool) {
        hasRequestedPermission = true
        isCheckingPermission = true
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
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
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
