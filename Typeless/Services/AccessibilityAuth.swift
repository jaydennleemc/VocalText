//
//  AccessibilityAuth.swift
//  Typeless
//

import ApplicationServices
import AppKit

/// Tracks macOS Accessibility trust (required for global shortcuts + paste).
@MainActor
enum AccessibilityAuth {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt system dialog if not trusted; always open Privacy pane as fallback.
    static func requestAccess() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if !trusted {
            openSystemSettings()
        }
    }

    static func openSystemSettings() {
        // macOS 13+ Settings app deep link; fall back to legacy pane.
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for s in candidates {
            if let url = URL(string: s), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// Path the user must enable in System Settings (Xcode builds ≠ /Applications).
    static var processPathHint: String {
        Bundle.main.bundlePath
    }

    static var isRunningFromXcodeDerivedData: Bool {
        Bundle.main.bundlePath.contains("DerivedData")
    }
}
