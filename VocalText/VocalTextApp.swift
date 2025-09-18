//
//  VocalTextApp.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

@main
struct VocalTextApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        // 移除 WindowGroup 以创建无窗口应用
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 拷贝预下载的模型到应用程序文档目录
        copyPreDownloadedModelsIfNeeded()
        
        // 初始化菜单栏控制器
        menuBarController = MenuBarController()
    }
    
    private func copyPreDownloadedModelsIfNeeded() {
        // 获取应用程序文档目录
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            print("无法获取文档目录")
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
                    print("模型目录已存在且不为空，跳过拷贝")
                    return
                }
            } catch {
                print("检查目标目录内容失败: \(error)")
            }
        }
        
        // 创建目标目录
        do {
            try fileManager.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("创建目标目录失败: \(error)")
            return
        }
        
        // 获取应用程序包中的预下载模型路径
        guard let sourcePath = Bundle.main.path(forResource: "Whisper/whisperkit-coreml", ofType: nil) else {
            print("未找到预下载的模型")
            return
        }
        
        print("源模型路径: \(sourcePath)")
        print("目标模型路径: \(targetPath)")
        
        // 拷贝模型文件
        do {
            // 获取源目录中的所有文件和文件夹
            let contents = try fileManager.contentsOfDirectory(atPath: sourcePath)
            
            for item in contents {
                let sourceItemPath = "\(sourcePath)/\(item)"
                let targetItemPath = "\(targetPath)/\(item)"
                
                // 检查目标路径是否已存在
                if fileManager.fileExists(atPath: targetItemPath) {
                    print("文件 \(item) 已存在，跳过拷贝")
                    continue
                }
                
                print("正在拷贝 \(item)...")
                try fileManager.copyItem(atPath: sourceItemPath, toPath: targetItemPath)
            }
            
            print("预下载模型拷贝完成")
        } catch {
            print("拷贝预下载模型失败: \(error)")
        }
    }
}
