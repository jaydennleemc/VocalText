//
//  MenuBarController.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import Cocoa
import SwiftUI
import Combine

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingController: NSHostingController<AnyView>!
    
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupMenuBar()
        setupLocalizationObserver()
    }
    
    private func setupMenuBar() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置状态栏图标
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VocalText")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 创建弹出窗口并设置初始内容
        popover = NSPopover()
        hostingController = NSHostingController(rootView: AnyView(MainView()))
        popover.contentViewController = hostingController
        popover.behavior = .transient
        
        // Set initial language
        updateLocale()
    }
    
    private func setupLocalizationObserver() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main) // Debounce to avoid rapid updates
            .sink { [weak self] _ in
                self?.updateLocale()
            }
            .store(in: &cancellables)
    }
    
    private func updateLocale() {
        let language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        hostingController.rootView = AnyView(MainView().environment(\.locale, .init(identifier: language)))
    }
    
    @objc private func statusBarButtonClicked() {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // 右键点击显示菜单
            setupMenu()
            statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            // 左键点击显示/隐藏弹出窗口
            toggleMainWindow()
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // 添加退出选项
        let quitItem = NSMenuItem(title: NSLocalizedString("general.quit.button", comment: ""), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleMainWindow() {
        // 切换主窗口的显示/隐藏
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
