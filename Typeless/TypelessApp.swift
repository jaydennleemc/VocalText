//
//  TypelessApp.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

@main
struct TypelessApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    var body: some Scene {
        // LSUIElement menu-bar app: no WindowGroup.
        // Settings / History are opened via AppWindows (NSWindow), not the Settings scene
        // — showSettingsWindow: is a no-op for many agent apps.
        Settings {
            // Keeps ⌘, wired by AppKit when available; content is unused — AppWindows hosts the real UI.
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()
        // Menu bar first — don't block UI on model copy / download.
        menuBarController = MenuBarController()
        // Bundled model copy (if any) off the main thread.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.copyPreDownloadedModelsIfNeeded()
        }
    }
    
    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            "QuickRecordShortcutEnabled": true,
            "QuickRecordShortcutKey": "cmd+shift+d"
        ]
        UserDefaults.standard.register(defaults: defaultValues)
        
        #if DEBUG
        print("📝 UserDefaults defaults registered: enabled=\(UserDefaults.standard.bool(forKey: "QuickRecordShortcutEnabled")), key=\(UserDefaults.standard.string(forKey: "QuickRecordShortcutKey") ?? "nil")")
        #endif
    }

    private func copyPreDownloadedModelsIfNeeded() {
        // 获取应用程序文档目录
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            #if DEBUG
            print("无法获取文档目录")
            #endif
            return
        }

        // 目标目录路径
        let targetPath = "\(documentsPath)/huggingface/models/argmaxinc/whisperkit-coreml"

        // 检查目标目录是否已存在模型
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: targetPath) {
            // 检查目录中是否有模型文件
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: targetPath)
                if !contents.isEmpty {
                    #if DEBUG
                    print("模型目錄已存在且不為空，跳過拷貝")
                    #endif
                    return
                }
            } catch {
                #if DEBUG
                print("檢查目標目錄內容失敗: \(error)")
                #endif
            }
        }

        // 创建目标目录
        do {
            try fileManager.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            #if DEBUG
            print("創建目標目錄失敗: \(error)")
            #endif
            return
        }

        // 获取应用程序包中的预下载模型路径
        guard let sourcePath = Bundle.main.path(forResource: "Whisper/whisperkit-coreml", ofType: nil) else {
            #if DEBUG
            print("未找到預下載的模型")
            #endif
            return
        }

        #if DEBUG
        print("源模型路徑: \(sourcePath)")
        print("目標模型路徑: \(targetPath)")
        #endif

        // 拷贝模型文件
        do {
            // 获取源目录中的所有文件和文件夹
            let contents = try fileManager.contentsOfDirectory(atPath: sourcePath)

            for item in contents {
                let sourceItemPath = "\(sourcePath)/\(item)"
                let targetItemPath = "\(targetPath)/\(item)"

                // 检查目标路径是否已存在
                if fileManager.fileExists(atPath: targetItemPath) {
                    #if DEBUG
                    print("文件 \(item) 已存在，跳過拷貝")
                    #endif
                    continue
                }

                #if DEBUG
                print("正在拷貝 \(item)...")
                #endif
                try fileManager.copyItem(atPath: sourceItemPath, toPath: targetItemPath)
            }

            #if DEBUG
            print("預下載模型拷貝完成")
            #endif
        } catch {
            #if DEBUG
            print("拷貝預下載模型失敗: \(error)")
            #endif
        }
    }
}
