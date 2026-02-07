//
//  SystemHealthChecker.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import Foundation
import AVFoundation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
import MachO

/// 系统健康检查器 - 处理边界条件和系统状态验证
class SystemHealthChecker: ObservableObject {
    @Published var healthStatus: HealthStatus = .checking
    @Published var issues: [HealthIssue] = []

    enum HealthStatus {
        case checking, healthy, warning, error
    }

    struct HealthIssue: Identifiable {
        let id = UUID()
        let type: IssueType
        let message: String
        let suggestion: String

        enum IssueType {
            case warning, error, info
        }
    }

    // MARK: - System Health Checks

    /// 检查系统整体健康状态
    func checkSystemHealth() async -> HealthStatus {
        var newIssues: [HealthIssue] = []

        // 检查麦克风权限
        let micPermission = await checkMicrophonePermission()
        if !micPermission {
            newIssues.append(HealthIssue(
                type: .error,
                message: "麦克风权限未授权",
                suggestion: "请在系统设置中授予麦克风权限"
            ))
        }

        // 检查音频设备
        let audioDevices = checkAudioDevices()
        if audioDevices.isEmpty {
            newIssues.append(HealthIssue(
                type: .error,
                message: "未检测到音频输入设备",
                suggestion: "请连接麦克风或检查音频设置"
            ))
        }

        // 检查存储空间（至少需要 2GB 可用空间用于模型下载）
        let storageCheck = checkStorageSpace()
        if !storageCheck.hasEnoughSpace {
            newIssues.append(HealthIssue(
                type: .error,
                message: "存储空间不足",
                suggestion: "需要至少 \(storageCheck.requiredSpace)GB 可用空间，当前可用 \(storageCheck.availableSpace)GB"
            ))
        }

        // 检查内存（至少需要 4GB 内存）
        let memoryCheck = checkMemory()
        if !memoryCheck.hasEnoughMemory {
            newIssues.append(HealthIssue(
                type: .warning,
                message: "内存可能不足",
                suggestion: "建议至少 4GB 内存以获得最佳体验，当前 \(memoryCheck.availableMemory)GB"
            ))
        }

        // 检查网络连接（用于模型下载）
        let networkCheck = await checkNetworkConnectivity()
        if !networkCheck.isConnected {
            newIssues.append(HealthIssue(
                type: .warning,
                message: "网络连接不可用",
                suggestion: "无法下载模型，需要网络连接"
            ))
        }

        // 检查 macOS 版本
        let osCheck = checkOSVersion()
        if !osCheck.isSupported {
            newIssues.append(HealthIssue(
                type: .error,
                message: "macOS 版本过低",
                suggestion: "需要 macOS 15.5 或更高版本"
            ))
        }

        // 检查 CPU 架构（Apple Silicon 优化）
        let cpuCheck = checkCPUArchitecture()
        if !cpuCheck.isAppleSilicon {
            newIssues.append(HealthIssue(
                type: .info,
                message: "使用 Intel CPU",
                suggestion: "Apple Silicon 设备上性能更佳"
            ))
        }

        // 检查是否在虚拟机中运行
        if isRunningInVirtualMachine() {
            newIssues.append(HealthIssue(
                type: .warning,
                message: "在虚拟机中运行",
                suggestion: "音频处理性能可能受影响"
            ))
        }

        // 检查系统负载
        let loadCheck = checkSystemLoad()
        if loadCheck.isHighLoad {
            newIssues.append(HealthIssue(
                type: .warning,
                message: "系统负载较高",
                suggestion: "建议关闭其他应用以释放资源"
            ))
        }

        // Update state on main actor
        let finalIssues = newIssues
        await MainActor.run {
            self.issues = finalIssues
            if finalIssues.isEmpty {
                self.healthStatus = .healthy
            } else if finalIssues.contains(where: { $0.type == .error }) {
                self.healthStatus = .error
            } else {
                self.healthStatus = .warning
            }
        }

        return self.healthStatus
    }

    /// 检查麦克风权限状态
    func checkMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// 检查音频设备可用性
    func checkAudioDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []

        // 使用 AVCaptureDevice 获取输入设备（macOS）
        #if os(macOS)
        let deviceSystem = AVCaptureDevice.devices(for: .audio)
        for device in deviceSystem {
            if device.hasMediaType(.audio) {
                devices.append(AudioDevice(name: device.localizedName, uniqueID: device.uniqueID))
            }
        }
        #endif

        // 如果没有找到设备，尝试使用 CoreAudio
        if devices.isEmpty {
            // 这里可以添加更底层的 CoreAudio 设备枚举
            // 作为备用方案
        }

        return devices
    }

    /// 检查存储空间
    func checkStorageSpace() -> (hasEnoughSpace: Bool, availableSpace: Double, requiredSpace: Double) {
        let fileManager = FileManager.default
        let requiredSpace: Double = 2.0 // GB

        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = attributes[.systemFreeSize] as? Double {
                let availableSpace = freeSpace / (1024 * 1024 * 1024) // Convert to GB
                return (availableSpace >= requiredSpace, availableSpace, requiredSpace)
            }
        } catch {
            #if DEBUG
            print("❌ Failed to check storage space: \(error)")
            #endif
        }

        return (false, 0.0, requiredSpace)
    }

    /// 检查内存
    func checkMemory() -> (hasEnoughMemory: Bool, availableMemory: Double) {
        // 使用 sysctl 获取物理内存大小（更简单可靠的方法）
        var size = 0
        sysctlbyname("hw.memsize", nil, &size, nil, 0)
        var memSize: UInt64 = 0
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)

        let totalMemoryGB = Double(memSize) / (1024.0 * 1024.0 * 1024.0)

        // 简单检查：如果总内存 >= 4GB，认为满足要求
        // 实际应用中可以更精确地计算可用内存，但这个方法更可靠
        return (totalMemoryGB >= 4.0, totalMemoryGB)
    }

    /// 检查网络连接
    func checkNetworkConnectivity() async -> (isConnected: Bool, speed: Double?) {
        // 简单的网络连接检查
        let task = URLSession.shared.dataTask(with: URL(string: "https://www.apple.com")!) { _, _, _ in }

        return await withCheckedContinuation { continuation in
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                task.cancel()
                continuation.resume(returning: (false, nil))
            }

            task.resume()

            // 使用 Task 监听完成
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒超时
                if task.state == .completed {
                    timeoutTimer.invalidate()
                    continuation.resume(returning: (true, nil))
                }
            }
        }
    }

    /// 检查 macOS 版本
    func checkOSVersion() -> (isSupported: Bool, version: String) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        // 需要 macOS 15.5+
        let isSupported = version.majorVersion > 15 ||
                         (version.majorVersion == 15 && version.minorVersion >= 5)

        return (isSupported, versionString)
    }

    /// 检查 CPU 架构
    func checkCPUArchitecture() -> (isAppleSilicon: Bool, architecture: String) {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let architecture = String(cString: machine)

        let isAppleSilicon = architecture.hasPrefix("arm64") || architecture.hasPrefix("Apple")

        return (isAppleSilicon, architecture)
    }

    /// 检查是否在虚拟机中运行
    func isRunningInVirtualMachine() -> Bool {
        // 检查常见的虚拟机指标
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model)

        // 检查常见的虚拟机型号
        let virtualMachines = ["VMware", "VirtualBox", "Parallels", "QEMU"]
        return virtualMachines.contains { modelString.contains($0) }
    }

    /// 检查系统负载
    func checkSystemLoad() -> (isHighLoad: Bool, loadAverage: Double) {
        var loadAverage: [Double] = [0, 0, 0]
        let result = getloadavg(&loadAverage, 3)

        if result == 0 {
            let avg = loadAverage[0] // 1分钟平均负载
            // 如果负载超过 CPU 核心数的一半，认为是高负载
            let processorCount = ProcessInfo.processInfo.processorCount
            let isHighLoad = avg > Double(processorCount) / 2.0
            return (isHighLoad, avg)
        }

        return (false, 0.0)
    }

    /// 检查临时文件目录是否可写
    func checkTempDirectoryWritable() -> Bool {
        let tempDir = NSTemporaryDirectory()
        let testFileName = "vocaltext_test_\(UUID().uuidString).tmp"
        let testFile = (tempDir as NSString).appendingPathComponent(testFileName)

        do {
            try "test".write(toFile: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testFile)
            return true
        } catch {
            #if DEBUG
            print("❌ Temp directory not writable: \(error)")
            #endif
            return false
        }
    }

    /// 检查应用程序是否具有必要的权限
    /// 注意：此方法需要异步调用，因为权限检查是异步的
    func checkAppPermissions() async -> [String] {
        var permissions: [String] = []

        // 检查麦克风权限
        let hasMicPermission = await checkMicrophonePermission()
        if !hasMicPermission {
            permissions.append("Microphone")
        }

        // 检查通知权限
        if #available(macOS 15.0, *) {
            let notificationCenter = UNUserNotificationCenter.current()
            let settings = await notificationCenter.notificationSettings()
            if settings.authorizationStatus != .authorized {
                permissions.append("Notifications")
            }
        }

        return permissions
    }

    /// 生成系统健康报告
    func generateHealthReport() -> String {
        var report = "VocalText 系统健康报告\n"
        report += "=====================\n\n"

        report += "状态: \(healthStatus)\n"
        report += "检测时间: \(Date())\n\n"

        if issues.isEmpty {
            report += "✅ 未发现健康问题\n"
        } else {
            report += "⚠️ 发现 \(issues.count) 个问题:\n\n"
            for (index, issue) in issues.enumerated() {
                report += "\(index + 1). [\(issue.type)] \(issue.message)\n"
                report += "   建议: \(issue.suggestion)\n\n"
            }
        }

        // 添加系统信息
        let osCheck = checkOSVersion()
        let cpuCheck = checkCPUArchitecture()
        let storageCheck = checkStorageSpace()
        let memoryCheck = checkMemory()

        report += "系统信息:\n"
        report += "- macOS 版本: \(osCheck.version)\n"
        report += "- CPU 架构: \(cpuCheck.architecture)\n"
        report += "- 可用存储: \(String(format: "%.2f", storageCheck.availableSpace))GB\n"
        report += "- 可用内存: \(String(format: "%.2f", memoryCheck.availableMemory))GB\n"

        return report
    }

    /// 显示健康检查结果的用户友好提示
    func getUserFriendlyMessage() -> String {
        switch healthStatus {
        case .healthy:
            return "系统状态良好，可以正常使用所有功能。"
        case .warning:
            return "发现一些警告，但核心功能可用。建议查看具体问题。"
        case .error:
            return "发现严重问题，某些功能可能无法使用。请检查并修复问题。"
        case .checking:
            return "正在检查系统状态..."
        }
    }
}

/// 音频设备结构体
struct AudioDevice: Identifiable {
    let id = UUID()
    let name: String
    let uniqueID: String
}
