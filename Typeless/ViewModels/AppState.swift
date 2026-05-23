import SwiftUI
import Combine

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Navigation

    enum Navigation: Equatable {
        case main
        case settings
        case tutorial
    }

    @Published var navigation: Navigation = .main

    // MARK: - Error State

    @Published var currentError: TypelessError?
    @Published var showErrorBanner = false
    @Published private(set) var isUserDismissed = false

    private var errorTimer: Timer?
    private var lastError: TypelessError?
    private var errorCount = 0

    // MARK: - Quick Record State

    @Published var isQuickRecording = false
    @Published var quickRecordCopied = false
    var quickRecordStartTime: Date?

    // MARK: - Navigation Methods

    func navigate(to destination: Navigation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            navigation = destination
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            navigation = .main
        }
    }

    // MARK: - Error Handling

    func showError(_ error: TypelessError) {
        // Detect duplicate errors
        if lastError == error {
            errorCount += 1
            if errorCount >= AppConstants.Error.maxConsecutiveErrors {
                print("⚠️ Repeated error: \(error.errorDescription ?? "Unknown")")
                return
            }
        } else {
            errorCount = 1
            lastError = error
        }

        currentError = error
        isUserDismissed = false

        withAnimation {
            showErrorBanner = true
        }

        // Clear previous timer
        errorTimer?.invalidate()

        // Set auto-dismiss duration based on error type
        let displayDuration: TimeInterval
        switch error.type {
        case .error: displayDuration = AppConstants.Error.autoDismissDurationError
        case .warning: displayDuration = AppConstants.Error.autoDismissDurationWarning
        case .info: displayDuration = AppConstants.Error.autoDismissDurationInfo
        }

        // Auto-dismiss for recoverable errors
        if error.isRecoverable {
            errorTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
                guard let self = self, !self.isUserDismissed else { return }
                withAnimation {
                    self.showErrorBanner = false
                }
            }
        }
    }

    func dismissError() {
        isUserDismissed = true
        errorTimer?.invalidate()
        errorTimer = nil
        withAnimation {
            showErrorBanner = false
        }
    }

    func cleanupErrorTimer() {
        errorTimer?.invalidate()
        errorTimer = nil
    }

    // MARK: - Quick Record

    func startQuickRecord() {
        isQuickRecording = true
        quickRecordStartTime = Date()
        quickRecordCopied = false
    }

    func stopQuickRecord() {
        isQuickRecording = false
        quickRecordStartTime = nil
    }

    func markQuickRecordCopied() {
        quickRecordCopied = true
    }

    // MARK: - Cleanup

    func reset() {
        navigation = .main
        cleanupErrorTimer()
        currentError = nil
        showErrorBanner = false
        isQuickRecording = false
        quickRecordStartTime = nil
        quickRecordCopied = false
    }
}

// MARK: - AudioTranscriberDelegate

extension AppState: AudioTranscriberDelegate {
    func audioTranscriber(_ transcriber: AudioTranscriber, didEncounterError error: TypelessError) {
        showError(error)
    }

    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateStatus status: String) {
        // Status updates are handled through published properties
    }

    func audioTranscriber(_ transcriber: AudioTranscriber, didUpdateProgress progress: Double) {
        // Progress updates are handled through published properties
    }
}