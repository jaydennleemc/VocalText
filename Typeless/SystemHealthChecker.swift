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
                message: NSLocalizedString("healthcheck.mic.permission.denied", comment: "Microphone permission not granted"),
                suggestion: NSLocalizedString("healthcheck.mic.permission.suggestion", comment: "Grant microphone permission in system settings")
            ))
        }

        // 检查音频设备
        let audioDevices = checkAudioDevices()
        if audioDevices.isEmpty {
            newIssues.append(HealthIssue(
                type: .error,
                message: NSLocalizedString("healthcheck.audio.no.device", comment: "No audio input device detected"),
                suggestion: NSLocalizedString("healthcheck.audio.device.suggestion", comment: "Connect microphone or check audio settings")
            ))
        }

        // 检查存储空间（至少需要 2GB 可用空间用于模型下载）
        let storageCheck = checkStorageSpace()
        if !storageCheck.hasEnoughSpace {
            newIssues.append(HealthIssue(
                type: .error,
                message: NSLocalizedString("healthcheck.storage.insufficient", comment: "Insufficient storage space"),
                suggestion: String(format: NSLocalizedString("healthcheck.storage.suggestion", comment: "Storage space suggestion with required and available space"), storageCheck.requiredSpace, storageCheck.availableSpace)
            ))
        }

        // 检查内存（至少需要 4GB 内存）
        let memoryCheck = checkMemory()
        if !memoryCheck.hasEnoughMemory {
            newIssues.append(HealthIssue(
                type: .warning,
                message: NSLocalizedString("healthcheck.memory.insufficient", comment: "Memory may be insufficient"),
                suggestion: String(format: NSLocalizedString("healthcheck.memory.suggestion", comment: "Memory suggestion with available memory"), memoryCheck.availableMemory)
            ))
        }

        // 检查网络连接（用于模型下载）
        let networkCheck = await checkNetworkConnectivity()
        if !networkCheck.isConnected {
            newIssues.append(HealthIssue(
                type: .warning,
                message: NSLocalizedString("healthcheck.network.unavailable", comment: "Network connection unavailable"),
                suggestion: NSLocalizedString("healthcheck.network.suggestion", comment: "Cannot download model, network connection required")
            ))
        }

        // 检查 macOS 版本
        let osCheck = checkOSVersion()
        if !osCheck.isSupported {
            newIssues.append(HealthIssue(
                type: .error,
                message: NSLocalizedString("healthcheck.os.unsupported", comment: "macOS version too low"),
                suggestion: NSLocalizedString("healthcheck.os.suggestion", comment: "Requires macOS 15.5 or higher")
            ))
        }

        // 检查 CPU 架构（Apple Silicon 优化）
        let cpuCheck = checkCPUArchitecture()
        if !cpuCheck.isAppleSilicon {
            newIssues.append(HealthIssue(
                type: .info,
                message: NSLocalizedString("healthcheck.cpu.intel", comment: "Using Intel CPU"),
                suggestion: NSLocalizedString("healthcheck.cpu.suggestion", comment: "Better performance on Apple Silicon devices")
            ))
        }

        // 检查是否在虚拟机中运行
        if isRunningInVirtualMachine() {
            newIssues.append(HealthIssue(
                type: .warning,
                message: NSLocalizedString("healthcheck.vm.detected", comment: "Running in virtual machine"),
                suggestion: NSLocalizedString("healthcheck.vm.suggestion", comment: "Audio processing performance may be affected")
            ))
        }

        // 检查系统负载
        let loadCheck = checkSystemLoad()
        if loadCheck.isHighLoad {
            newIssues.append(HealthIssue(
                type: .warning,
                message: NSLocalizedString("healthcheck.load.high", comment: "High system load"),
                suggestion: NSLocalizedString("healthcheck.load.suggestion", comment: "Close other applications to free up resources")
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
    func checkAudioDevices() -> [AudioDeviceModel] {
        var devices: [AudioDeviceModel] = []

        #if os(macOS)
        let deviceSystem = AVCaptureDevice.devices(for: .audio)
        for device in deviceSystem where device.hasMediaType(.audio) {
            devices.append(AudioDeviceModel(
                id: AudioDeviceID(bitPattern: 0),
                name: device.localizedName,
                uniqueID: device.uniqueID
            ))
        }
        #endif

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
        guard let url = URL(string: "https://www.apple.com") else {
            return (false, nil)
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, nil)
            }
            return (httpResponse.statusCode == 200, nil)
        } catch {
            return (false, nil)
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
            permissions.append(NSLocalizedString("healthcheck.permission.microphone", comment: "Microphone"))
        }

        // 检查通知权限
        if #available(macOS 15.0, *) {
            let notificationCenter = UNUserNotificationCenter.current()
            let settings = await notificationCenter.notificationSettings()
            if settings.authorizationStatus != .authorized {
                permissions.append(NSLocalizedString("healthcheck.permission.notifications", comment: "Notifications"))
            }
        }

        return permissions
    }

    /// 生成系统健康报告
    func generateHealthReport() -> String {
        var report = NSLocalizedString("healthcheck.report.title", comment: "VocalText System Health Report") + "\n"
        report += "=====================\n\n"

        report += NSLocalizedString("healthcheck.report.status", comment: "Status") + ": \(healthStatus)\n"
        report += NSLocalizedString("healthcheck.report.time", comment: "Check time") + ": \(Date())\n\n"

        if issues.isEmpty {
            report += NSLocalizedString("healthcheck.report.no.issues", comment: "No health issues found") + "\n"
        } else {
            report += String(format: NSLocalizedString("healthcheck.report.issues.found", comment: "Found N issues"), issues.count) + ":\n\n"
            for (index, issue) in issues.enumerated() {
                report += "\(index + 1). [\(issue.type)] \(issue.message)\n"
                report += NSLocalizedString("healthcheck.report.suggestion", comment: "Suggestion") + ": \(issue.suggestion)\n\n"
            }
        }

        // 添加系统信息
        let osCheck = checkOSVersion()
        let cpuCheck = checkCPUArchitecture()
        let storageCheck = checkStorageSpace()
        let memoryCheck = checkMemory()

        report += NSLocalizedString("healthcheck.report.system.info", comment: "System Information") + ":\n"
        report += "- " + NSLocalizedString("healthcheck.report.macos.version", comment: "macOS Version") + ": \(osCheck.version)\n"
        report += "- " + NSLocalizedString("healthcheck.report.cpu.arch", comment: "CPU Architecture") + ": \(cpuCheck.architecture)\n"
        report += "- " + NSLocalizedString("healthcheck.report.storage.available", comment: "Available Storage") + ": \(String(format: "%.2f", storageCheck.availableSpace))GB\n"
        report += "- " + NSLocalizedString("healthcheck.report.memory.available", comment: "Available Memory") + ": \(String(format: "%.2f", memoryCheck.availableMemory))GB\n"

        return report
    }

    /// 显示健康检查结果的用户友好提示
    func getUserFriendlyMessage() -> String {
        switch healthStatus {
        case .healthy:
            return NSLocalizedString("healthcheck.status.healthy.message", comment: "System status good, all features available")
        case .warning:
            return NSLocalizedString("healthcheck.status.warning.message", comment: "Some warnings found, core features available")
        case .error:
            return NSLocalizedString("healthcheck.status.error.message", comment: "Serious issues found, some features may not work")
        case .checking:
            return NSLocalizedString("healthcheck.status.checking.message", comment: "Checking system status")
        }
    }
}


