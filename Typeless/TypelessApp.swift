//
//  TypelessApp.swift
//  Typeless
//
//  Pure AppKit entry (LSUIElement). No SwiftUI App / Settings scene —
//  ⌘, and windows are owned by MenuBarController + AppWindows.
//

import AppKit

@main
enum TypelessMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "QuickRecordShortcutEnabled": true,
            "QuickRecordShortcutKey": "cmd+shift+d",
        ])
        // LSUIElement in Info.plist; keep accessory so we never take Dock focus.
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
