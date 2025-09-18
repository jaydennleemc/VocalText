//
//  MenuBarController.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import AppKit
import SwiftUI

class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    
    override init() {
        super.init()
        setupStatusBarItem()
    }
    
    private func setupStatusBarItem() {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置状态栏图标
        if let button = statusItem.button {
            // 使用系统图标
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            button.action = #selector(showPopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp]) // 监听左右键点击
        }
    }
    
    @objc private func showPopover(_ sender: AnyObject?) {
        // 检查是左键还是右键点击
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // 右键点击显示菜单
            showContextMenu()
            return
        }
        
        // 如果popover已经显示，则关闭它
        if popover.isShown {
            closePopover(sender)
            return
        }
        
        // 创建主视图
        let mainView = MainView()
        let hostingController = NSHostingController(rootView: mainView)
        
        // 设置popover内容大小
        hostingController.view.frame = NSMakeRect(0, 0, 400, 300)
        
        // 配置popover
        popover.contentViewController = hostingController
        popover.behavior = .applicationDefined // 不会自动关闭，需要手动控制
        
        // 显示popover
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        
        // 确保popover在应用程序激活时显示
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // 重置菜单以恢复popover功能
    }
    
    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
    
    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}