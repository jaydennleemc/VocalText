//
//  KeyboardShortcutManager.swift
//  Typeless
//

import Cocoa
import Carbon
import ApplicationServices

/// Hold-to-dictate: Carbon starts on key combo press; a poll timer ends when combo is released.
/// (Key-up alone is unreliable with RegisterEventHotKey — sessions died ~1s early.)
final class KeyboardShortcutManager {
    private weak var menuBarController: MenuBarController?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var holdPollTimer: Timer?
    private var trustObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    private(set) var isQuickRecordInProgress = false
    private var dictateStartedAt: Date?
    /// Don't honor "released" until this long after start (Bluetooth needs warm-up).
    private let minHoldBeforeRelease: TimeInterval = 0.55
    /// How often to sample physical key state while holding.
    private let holdPollInterval: TimeInterval = 0.05
    private var releasedPollCount = 0

    fileprivate static weak var shared: KeyboardShortcutManager?

    private let enabledKey = "QuickRecordShortcutEnabled"
    private let shortcutKey = "QuickRecordShortcutKey"
    private let defaultShortcut = "cmd+shift+d"
    private var installedShortcutSignature = ""
    private var wasTrusted = false

    init(menuBarController: MenuBarController) {
        self.menuBarController = menuBarController
        Self.shared = self
        wasTrusted = AXIsProcessTrusted()

        if UserDefaults.standard.string(forKey: shortcutKey) == "cmd+shift+v" {
            UserDefaults.standard.set(defaultShortcut, forKey: shortcutKey)
        }
        if UserDefaults.standard.object(forKey: shortcutKey) == nil {
            UserDefaults.standard.set(defaultShortcut, forKey: shortcutKey)
        }

        installAll()
        startWatching()
    }

    // MARK: - Install

    func installAll() {
        let signature = "\(isEnabled)|\(shortcutString)"
        uninstallHotKeyOnly()
        installedShortcutSignature = signature
        guard isEnabled else { return }
        registerCarbonHotKey()
        #if DEBUG
        print("⌨️ Hotkey \(shortcutString) carbon=\(hotKeyRef != nil)")
        #endif
    }

    // MARK: - Session (single state machine)

    /// Menu toggle start — marks session active so Carbon won't double-start.
    /// No hold-poll (user stops via menu).
    func beginMenuSession() {
        guard !isQuickRecordInProgress else { return }
        isQuickRecordInProgress = true
        dictateStartedAt = Date()
        releasedPollCount = 0
    }

    /// Clear session flags / hold-poll. Does not stop audio (caller does).
    func endSession() {
        isQuickRecordInProgress = false
        dictateStartedAt = nil
        stopHoldPolling()
    }

    private func beginHoldSession() {
        isQuickRecordInProgress = true
        dictateStartedAt = Date()
        releasedPollCount = 0
        startHoldPolling()
    }

    private func uninstallHotKeyOnly() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    private var shortcutString: String {
        UserDefaults.standard.string(forKey: shortcutKey) ?? defaultShortcut
    }

    // MARK: - Carbon press → start

    private func registerCarbonHotKey() {
        guard let parsed = Self.parseShortcut(shortcutString) else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            typelessHotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        guard status == noErr else { return }

        var hotKeyID = EventHotKeyID(signature: OSType(0x54504C53), id: 1)
        _ = RegisterEventHotKey(
            parsed.keyCode,
            parsed.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    fileprivate func carbonHotKeyPressed() {
        guard isEnabled else { return }
        // Second press / menu session already active → hold mode, not toggle.
        guard !isQuickRecordInProgress else { return }

        #if DEBUG
        print("⌨️ Dictate START (hold)")
        #endif

        beginHoldSession()
        Task { @MainActor in
            self.menuBarController?.startQuickRecord()
        }
    }

    // MARK: - Hold polling (authoritative end condition)

    private func startHoldPolling() {
        stopHoldPolling()
        let timer = Timer(timeInterval: holdPollInterval, repeats: true) { [weak self] _ in
            self?.pollHoldState()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdPollTimer = timer
    }

    private func stopHoldPolling() {
        holdPollTimer?.invalidate()
        holdPollTimer = nil
        releasedPollCount = 0
    }

    private func pollHoldState() {
        guard isQuickRecordInProgress else {
            stopHoldPolling()
            return
        }
        // Don't stop during the first moments (key settle / Carbon quirks).
        if let start = dictateStartedAt, Date().timeIntervalSince(start) < minHoldBeforeRelease {
            return
        }

        if isShortcutPhysicallyHeld() {
            releasedPollCount = 0
            return
        }

        // Require 2 consecutive "released" samples (~100ms) to avoid flicker.
        releasedPollCount += 1
        if releasedPollCount >= 2 {
            #if DEBUG
            print("⌨️ Dictate END (keys released)")
            #endif
            endDictate()
        }
    }

    /// True while the user is still holding the shortcut.
    ///
    /// After `RegisterEventHotKey`, the letter key is often swallowed so
    /// `keyState` reports "up" even while held. We treat **required modifiers
    /// still down** as "holding" (e.g. keep ⌘⇧ pressed while speaking; release
    /// them to stop). If there are no modifiers, fall back to the letter key.
    private func isShortcutPhysicallyHeld() -> Bool {
        guard let parsed = Self.parseShortcut(shortcutString) else { return false }

        let flags = CGEventSource.flagsState(.hidSystemState)
        let needCmd = parsed.nsModifiers.contains(.command)
        let needShift = parsed.nsModifiers.contains(.shift)
        let needOpt = parsed.nsModifiers.contains(.option)
        let needCtrl = parsed.nsModifiers.contains(.control)
        let needsAnyModifier = needCmd || needShift || needOpt || needCtrl

        if needsAnyModifier {
            if needCmd && !flags.contains(.maskCommand) { return false }
            if needShift && !flags.contains(.maskShift) { return false }
            if needOpt && !flags.contains(.maskAlternate) { return false }
            if needCtrl && !flags.contains(.maskControl) { return false }
            return true
        }

        return CGEventSource.keyState(.hidSystemState, key: CGKeyCode(parsed.keyCode))
    }

    private func endDictate() {
        guard isQuickRecordInProgress else { return }
        endSession()
        Task { @MainActor in
            self.menuBarController?.stopQuickRecord()
        }
    }

    // MARK: - Watch

    private func startWatching() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refreshTrust() }

        trustObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.refreshTrust()
            }
        }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let sig = "\(self.isEnabled)|\(self.shortcutString)"
            if sig != self.installedShortcutSignature {
                self.installAll()
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshTrust()
        }
        if let pollTimer { RunLoop.main.add(pollTimer, forMode: .common) }
    }

    private func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        if trusted != wasTrusted {
            wasTrusted = trusted
            NotificationCenter.default.post(name: .accessibilityTrustChanged, object: trusted)
        }
        if isEnabled, hotKeyRef == nil {
            installAll()
        }
    }

    // MARK: - Parse

    struct ParsedShortcut {
        let keyCode: UInt32
        let carbonModifiers: UInt32
        let nsModifiers: NSEvent.ModifierFlags
    }

    static func parseShortcut(_ string: String) -> ParsedShortcut? {
        let parts = string.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyPart = parts.last, !keyPart.isEmpty else { return nil }

        var carbon: UInt32 = 0
        var ns: NSEvent.ModifierFlags = []
        for p in parts.dropLast() {
            switch p {
            case "cmd", "command", "⌘": carbon |= UInt32(cmdKey); ns.insert(.command)
            case "shift", "⇧": carbon |= UInt32(shiftKey); ns.insert(.shift)
            case "option", "opt", "alt", "⌥": carbon |= UInt32(optionKey); ns.insert(.option)
            case "control", "ctrl", "⌃": carbon |= UInt32(controlKey); ns.insert(.control)
            default: break
            }
        }
        guard let code = keyCode(for: keyPart) else { return nil }
        return ParsedShortcut(keyCode: code, carbonModifiers: carbon, nsModifiers: ns)
    }

    private static func keyCode(for key: String) -> UInt32? {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "space": kVK_Space,
        ]
        return map[key].map { UInt32($0) }
    }

    func setupAppMenuShortcuts() {
        guard NSApp.mainMenu == nil else { return }
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(
            title: "About Typeless",
            action: #selector(NSApp.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        let prefs = NSMenuItem(
            title: "Settings…",
            action: #selector(MenuBarController.openSettingsAction),
            keyEquivalent: ","
        )
        prefs.target = menuBarController
        appMenu.addItem(prefs)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Quit Typeless",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        ))
        NSApp.mainMenu = mainMenu
    }

    deinit {
        stopHoldPolling()
        uninstallHotKeyOnly()
        pollTimer?.invalidate()
        if let trustObserver {
            DistributedNotificationCenter.default().removeObserver(trustObserver)
        }
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        if Self.shared === self { Self.shared = nil }
    }
}

extension Notification.Name {
    static let accessibilityTrustChanged = Notification.Name("TypelessAccessibilityTrustChanged")
}

private func typelessHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    KeyboardShortcutManager.shared?.carbonHotKeyPressed()
    return noErr
}
