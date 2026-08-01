//
//  TextInserter.swift
//  Typeless
//

import AppKit
import ApplicationServices

/// Commits dictation into the frontmost app's focused field.
/// Preference order:
/// 1. Accessibility `kAXSelectedTextAttribute` (true insert at caret)
/// 2. Clipboard + synthetic ⌘V
/// Always leaves the text on the general pasteboard as a fallback.
enum TextInserter {
    /// Returns `true` when text was delivered into a target field (AX or paste attempted with trust).
    @MainActor
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Always copy so user can ⌘V manually if auto-insert fails.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)

        // 1) Direct AX insert into focused element (best for text fields / inputs).
        if AccessibilityAuth.isTrusted, insertViaAccessibility(trimmed) {
            #if DEBUG
            print("⌨️ Inserted via Accessibility selected-text")
            #endif
            return true
        }

        // 2) Synthetic ⌘V — needs Accessibility for CGEvent.
        guard AccessibilityAuth.isTrusted else {
            #if DEBUG
            print("📋 Copied only (no Accessibility — enable in Settings to auto-insert)")
            #endif
            return false
        }

        // Brief delay lets the focused app settle after hotkey release / overlay phase change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            // Re-assert clipboard in case another app mutated it.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(trimmed, forType: .string)
            postCommandV()
            #if DEBUG
            print("⌨️ Posted ⌘V paste")
            #endif
        }
        return true
    }

    // MARK: - Accessibility insert

    /// Inserts by replacing the current selection (empty selection ⇒ insert at caret).
    private static func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusStatus == .success, let focusedRef else {
            #if DEBUG
            print("⌨️ AX: no focused element")
            #endif
            return false
        }
        let focused = focusedRef as! AXUIElement

        // Preferred: set selected text (works in most AppKit / many Electron fields).
        var err = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        if err == .success { return true }

        // Fallback: if the element exposes a string value + selected range, splice in.
        if insertBySplicingValue(focused, text: text) {
            return true
        }

        #if DEBUG
        print("⌨️ AX selected-text failed: \(err.rawValue)")
        #endif
        return false
    }

    private static func insertBySplicingValue(_ element: AXUIElement, text: String) -> Bool {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let current = valueRef as? String
        else { return false }

        var rangeRef: CFTypeRef?
        var location = current.utf16.count
        var length = 0

        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef,
           CFGetTypeID(rangeRef) == AXValueGetTypeID() {
            let axValue = rangeRef as! AXValue
            var cfRange = CFRange()
            if AXValueGetValue(axValue, .cfRange, &cfRange) {
                location = cfRange.location
                length = cfRange.length
            }
        }

        // Build new string using UTF-16 indices (AX ranges are UTF-16 based).
        let utf16 = Array(current.utf16)
        let clampedStart = location < 0 ? 0 : min(location, utf16.count)
        let rawEnd = clampedStart + (length < 0 ? 0 : length)
        let clampedEnd = rawEnd < clampedStart ? clampedStart : min(rawEnd, utf16.count)

        let prefixUnits = Array(utf16.prefix(clampedStart))
        let suffixUnits = Array(utf16.suffix(from: clampedEnd))
        let prefix = String(utf16CodeUnits: prefixUnits, count: prefixUnits.count)
        let suffix = String(utf16CodeUnits: suffixUnits, count: suffixUnits.count)
        let merged = prefix + text + suffix

        let setErr = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            merged as CFTypeRef
        )
        guard setErr == .success else { return false }

        // Place caret after inserted text.
        let newCaret = clampedStart + text.utf16.count
        var newRange = CFRange(location: newCaret, length: 0)
        if let axRange = AXValueCreate(.cfRange, &newRange) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                axRange
            )
        }
        return true
    }

    // MARK: - ⌘V

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 0x09 // kVK_ANSI_V

        // Clear leftover modifiers from the dictate shortcut (e.g. ⌘⇧) so ⌘V is clean.
        if let flagsUp = CGEvent(source: source) {
            flagsUp.type = .flagsChanged
            flagsUp.flags = []
            flagsUp.post(tap: .cghidEventTap)
        }

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
