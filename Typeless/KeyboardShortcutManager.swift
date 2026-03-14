//
//  KeyboardShortcutManager.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import Cocoa
import SwiftUI

/// 管理全局键盘快捷键
class KeyboardShortcutManager {
    private var eventMonitor: Any?
    private var quickRecordKeyUpMonitor: Any?
    private weak var menuBarController: MenuBarController?
    private weak var mainViewDelegate: MainViewDelegate?
    
    // MARK: - Quick Record Hold State
    /// 快速录音按住状态
    private(set) var isQuickRecordInProgress: Bool = false
    
    // MARK: - UserDefaults Keys
    private let quickRecordShortcutEnabledKey = "QuickRecordShortcutEnabled"
    private let quickRecordShortcutKeyKey = "QuickRecordShortcutKey"
    
    /// 默认快捷键: cmd+shift+v
    private let defaultQuickRecordShortcut = "cmd+shift+v"

    init(menuBarController: MenuBarController) {
        self.menuBarController = menuBarController
        self.mainViewDelegate = menuBarController
        setupGlobalHotkeys()
    }

    /// 设置全局键盘快捷键监听器
    private func setupGlobalHotkeys() {
        // 监听全局键盘按下事件（即使应用不在焦点）
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // 监听全局键盘释放事件
        quickRecordKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUpEvent(event)
        }
    }

    /// 处理键盘事件
    private func handleKeyEvent(_ event: NSEvent) {
        // 检查是否有修饰键
        let hasCommand = event.modifierFlags.contains(.command)
        let hasControl = event.modifierFlags.contains(.control)
        let hasOption = event.modifierFlags.contains(.option)

        // CMD + R: 开始/停止录音
        if hasCommand && event.charactersIgnoringModifiers == "r" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+R (Toggle Recording)")
            #endif
            mainViewDelegate?.toggleRecording()
            return
        }

        // CMD + C: 复制转录文本
        if hasCommand && event.charactersIgnoringModifiers == "c" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+C (Copy Transcript)")
            #endif
            mainViewDelegate?.copyTranscript()
            return
        }

        // CMD + S: 打开设置
        if hasCommand && event.charactersIgnoringModifiers == "s" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+S (Open Settings)")
            #endif
            mainViewDelegate?.openSettings()
            return
        }

        // CMD + ,: 打开设置（macOS 标准）
        if hasCommand && event.charactersIgnoringModifiers == "," {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+, (Open Settings)")
            #endif
            mainViewDelegate?.openSettings()
            return
        }

        // CMD + Q: 退出应用（系统默认，但我们可以添加确认）
        if hasCommand && event.charactersIgnoringModifiers == "q" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+Q (Quit App)")
            #endif
            // 可以在这里添加退出确认对话框
            return
        }

        // CMD + W: 关闭弹窗
        if hasCommand && event.charactersIgnoringModifiers == "w" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+W (Close Popover)")
            #endif
            mainViewDelegate?.closePopover()
            return
        }

        // CMD + T: 显示教程
        if hasCommand && event.charactersIgnoringModifiers == "t" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: CMD+T (Show Tutorial)")
            #endif
            mainViewDelegate?.showTutorial()
            return
        }

        // OPT + CMD + R: 强制重试下载
        if hasCommand && hasOption && event.charactersIgnoringModifiers == "r" {
            #if DEBUG
            print("⌨️ Keyboard shortcut: OPT+CMD+R (Force Retry Download)")
            #endif
            mainViewDelegate?.forceRetryDownload()
            return
        }
        
        // 快速录音快捷键按下检测 (cmd+shift+v)
        if isQuickRecordShortcut(event: event) {
            #if DEBUG
            print("⌨️ Quick Record: Key Down detected")
            #endif
            isQuickRecordInProgress = true
            mainViewDelegate?.startQuickRecord()
        }
    }
    
    /// 处理键盘释放事件
    private func handleKeyUpEvent(_ event: NSEvent) {
        // 检查快速录音快捷键是否释放
        if isQuickRecordInProgress && isQuickRecordShortcut(event: event) {
            #if DEBUG
            print("⌨️ Quick Record: Key Up detected")
            #endif
            isQuickRecordInProgress = false
            mainViewDelegate?.stopQuickRecord()
        }
    }
    
    /// 检查是否为快速录音快捷键
    private func isQuickRecordShortcut(event: NSEvent) -> Bool {
        guard UserDefaults.standard.bool(forKey: quickRecordShortcutEnabledKey) else {
            return false
        }
        
        let shortcutString = UserDefaults.standard.string(forKey: quickRecordShortcutKeyKey) ?? defaultQuickRecordShortcut
        let parsedShortcut = parseShortcut(shortcutString)
        
        let modifiers = event.modifierFlags
        let hasRequiredModifiers = modifiers.contains(.command) && modifiers.contains(.shift)
        let characterMatches = event.charactersIgnoringModifiers?.lowercased() == parsedShortcut.key.lowercased()
        
        return hasRequiredModifiers && characterMatches
    }
    
    private func parseShortcut(_ shortcutString: String) -> (key: String, modifiers: [String]) {
        let parts = shortcutString.lowercased().components(separatedBy: "+")
        
        guard parts.count >= 2 else {
            return (key: shortcutString, modifiers: [])
        }
        
        return (key: parts.last ?? "", modifiers: Array(parts.dropLast()))
    }

    /// 注册应用内快捷键（通过 NSMenuItem）
    func setupAppMenuShortcuts() {
        // 这些快捷键会在应用获得焦点时工作
        // 主要用于菜单栏项目的键盘导航

        let appMenu = NSApp.mainMenu

        // 创建应用菜单
        if appMenu == nil {
            let mainMenu = NSMenu()

            // 应用菜单
            let appMenuItem = NSMenuItem()
            mainMenu.addItem(appMenuItem)

            let appSubMenu = NSMenu()
            appMenuItem.submenu = appSubMenu

            // 关于
            let aboutItem = NSMenuItem(
                title: "About VocalText",
                action: #selector(NSApp.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""
            )
            appSubMenu.addItem(aboutItem)

            appSubMenu.addItem(NSMenuItem.separator())

            // 首选项 (CMD + ,)
            let preferencesItem = NSMenuItem(
                title: "Preferences…",
                action: #selector(openSettingsFromMenu),
                keyEquivalent: ","
            )
            preferencesItem.target = self
            appSubMenu.addItem(preferencesItem)

            appSubMenu.addItem(NSMenuItem.separator())

            // 退出
            let quitItem = NSMenuItem(
                title: "Quit VocalText",
                action: #selector(NSApp.terminate(_:)),
                keyEquivalent: "q"
            )
            appSubMenu.addItem(quitItem)

            NSApp.mainMenu = mainMenu
        }
    }

    @objc private func openSettingsFromMenu() {
        mainViewDelegate?.openSettings()
    }

    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let keyUpMonitor = quickRecordKeyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
        }
        #if DEBUG
        print("⌨️ KeyboardShortcutManager deinit")
        #endif
    }
}

/// 协议用于与 MainView 通信
protocol MainViewDelegate: AnyObject {
    func toggleRecording()
    func copyTranscript()
    func openSettings()
    func closePopover()
    func showTutorial()
    func forceRetryDownload()
    func startQuickRecord()
    func stopQuickRecord()
}
