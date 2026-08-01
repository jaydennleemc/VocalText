//
//  AppWindows.swift
//  Typeless
//

import AppKit
import SwiftUI

/// Window host for agent (LSUIElement) apps.
/// SwiftUI `Settings { }` + `showSettingsWindow:` is unreliable without a Dock icon.
@MainActor
enum AppWindows {
    private static var settingsWindow: NSWindow?
    private static var historyWindow: NSWindow?

    static func openSettings() {
        present(
            existing: &settingsWindow,
            title: NSLocalizedString("settings.view.title", comment: "Settings"),
            size: NSSize(width: 520, height: 400),
            minSize: NSSize(width: 480, height: 360)
        ) {
            SettingsView(isPresented: Binding(
                get: { true },
                set: { if !$0 { settingsWindow?.close() } }
            ))
            .environmentObject(AudioTranscriber.shared)
        }
    }

    static func openHistory() {
        present(
            existing: &historyWindow,
            title: "History",
            size: NSSize(width: 380, height: 360),
            minSize: NSSize(width: 320, height: 280)
        ) {
            HistoryView()
        }
    }

    // MARK: - Shared presenter

    private static func present<Content: View>(
        existing: inout NSWindow?,
        title: String,
        size: NSSize,
        minSize: NSSize,
        @ViewBuilder content: () -> Content
    ) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = existing {
            // Recreate content if needed so settings always see current state
            if !window.isVisible {
                window.contentViewController = NSHostingController(rootView: content())
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = hosting
        window.setContentSize(size)
        window.minSize = minSize
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        // Agent apps sometimes need an explicit level bump after activate
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        existing = window
    }
}
