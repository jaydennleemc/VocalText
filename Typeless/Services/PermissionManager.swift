import Foundation
import AVFoundation
import AppKit

// MARK: - Permission Manager

@MainActor
final class PermissionManager {
    /// Warm mic permission at launch (non-blocking). Prompts only if not determined.
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }

    /// Awaitable grant for dictate start path.
    func ensurePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            showMicrophoneSettingsAlert()
            return false
        case .notDetermined:
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    cont.resume(returning: ok)
                }
            }
            if !granted { showMicrophoneSettingsAlert() }
            return granted
        @unknown default:
            return false
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
