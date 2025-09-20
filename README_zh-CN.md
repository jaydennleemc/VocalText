# VocalText 🎙️
> 适用于 macOS 的实时语音转文字工具 - 注重隐私，支持离线使用

[![](https://img.shields.io/badge/平台-macOS-blue)](https://www.apple.com/macos)
[![](https://img.shields.io/badge/语言-Swift-orange)](https://swift.org)
[![](https://img.shields.io/github/license/jaydennleemc/VocalText)](LICENSE)
[![](https://img.shields.io/github/v/release/jaydennleemc/VocalText)](https://github.com/jaydennleemc/VocalText/releases)

通过 VocalText 即时将您的语音转换为文字 - 这款注重隐私的 macOS 菜单栏应用可完全离线工作。非常适合做笔记、采访、讲座和随时随地捕捉想法！

## 🌟 功能特点

- 🕵️‍♂️ **100% 隐私保护** - 所有处理都在您的设备上进行，数据不会离开您的 Mac
- ⚡ **实时转录** - 边说边看文字出现
- 📶 **离线优先** - 初始设置后无需网络连接即可工作
- 🎛️ **多语言支持** - 支持英语、中文、西班牙语、法语等 90 多种语言转录
- 📊 **实时可视化** - 录制期间显示 iOS 风格的波形图
- 🎛️ **质量选项** - 可选择 Tiny、Base、Small 或 Medium 模型
- 🎧 **音频设备选择** - 可使用任何连接的麦克风或音频输入设备
- 📋 **一键复制** - 瞬间将转录文本复制到剪贴板
- 🎨 **极简设计** - 安静地驻留在您的菜单栏中

## 🚀 快速开始

### 安装
1. 从 [发布页面](https://github.com/jaydennleemc/VocalText/releases) 下载最新版本
2. 解压 `.zip` 文件
3. 将 `VocalText.app` 拖拽到您的应用程序文件夹
4. 启动应用并按照首次设置操作

### 首次使用
```bash
# 首次启动时，VocalText 将：
# 1. 引导您完成快速教程
# 2. 下载默认转录模型 (~300MB)
# 3. 请求麦克风访问权限
```

### 日常使用
1. 点击 macOS 菜单栏中的波形图标
2. 按下大麦克风按钮开始录制
3. 清晰地说话 - 查看实时波形可视化
4. 完成后按下停止按钮
5. 点击转录文本将其复制到剪贴板

## 🛠️ 命令和用法

### 基本工作流程
```bash
# 开始录制
点击菜单栏图标 → 点击大麦克风按钮

# 停止录制
点击红色停止按钮

# 复制文本
点击转录文本 → 自动复制到剪贴板
```

### 访问设置
```bash
# 打开设置
点击主窗口中的齿轮图标

# 可用设置：
# - 模型选择 (Tiny, Base, Small, Medium)
# - 音频设备选择
# - 语言选择
```

### 模型选项
| 模型 | 大小 | 准确度 | 速度 | 最佳用途 |
|-------|------|----------|-------|----------|
| Tiny | ~75MB | 低 | 快 | 快速笔记，对准确度要求不高 |
| Base | ~150MB | 中 | 中 | 一般用途转录 |
| Small | ~480MB | 高 | 慢 | 大多数使用场景，平衡性好 |
| Medium | ~1.5GB | 很高 | 很慢 | 专业转录 |

## 🧠 技术栈

- **SwiftUI** - 现代化声明式 UI 框架
- **AVFoundation** - Apple 音频录制和处理框架
- **WhisperKit** - 设备端语音识别框架
- **CoreAudio** - 低级音频处理功能
- **AppKit** - macOS 应用程序基础

## 🔧 高级用法

### 自定义音频设备
- VocalText 自动检测连接的音频设备
- 在设置中选择您偏好的输入设备
- 适合专业麦克风或音频接口

### 语言选择
- 支持 90 多种语言
- 在设置中更改语言
- 模型会自动适应所选语言

### 质量与速度权衡
- 较小模型 (Tiny, Base) = 处理速度快，准确度低
- 较大模型 (Small, Medium) = 处理速度慢，准确度高
- 根据您的需求选择：快速笔记 vs 专业转录

## 🛡️ 隐私与安全

### 您的数据保持私密
- 🔒 没有音频数据会离开您的设备
- 🔒 转录无需互联网连接
- 🔒 无用户跟踪或分析
- 🔒 模型在您的设备上加密存储
- 🔒 开源 - 您可以自行验证代码

### 权限
- **麦克风访问** - 仅在您按下录制按钮时用于录制
- **辅助功能** - 可选，用于增强剪贴板集成

## 💰 价格

### 完全免费
- 💸 无订阅费用
- 💸 无高级功能
- 💸 无隐藏成本
- 💸 开源且永久免费

### 一次性成本
- 初始模型下载 (~300MB-1.5GB，取决于所选模型)
- 下载时按标准网络数据费率计费

## 🤝 贡献

喜欢 VocalText 吗？帮助我们让它变得更好！

### 贡献方式
- 🐛 通过创建 [Issues](https://github.com/jaydennleemc/VocalText/issues) 报告错误
- 💡 通过创建 [Issues](https://github.com/jaydennleemc/VocalText/issues) 建议功能
- 📝 通过提交 PR 改进文档
- 🔧 通过 [Pull Requests](https://github.com/jaydennleemc/VocalText/pulls) 提交代码改进
- ⭐ 给这个仓库加星以表示支持

### 开发设置
```bash
# 克隆仓库
git clone https://github.com/jaydennleemc/VocalText.git

# 在 Xcode 中打开
open VocalText.xcodeproj

# 构建和运行
# 在 Xcode 中按 CMD+R
```

## 📚 了解更多

### 相关资源
- [WhisperKit 文档](https://github.com/argmaxinc/WhisperKit)
- [Apple AVFoundation 指南](https://developer.apple.com/av-foundation/)
- [SwiftUI 教程](https://developer.apple.com/tutorials/swiftui)

### 社区
- [GitHub 讨论](https://github.com/jaydennleemc/VocalText/discussions)
- [Twitter](https://twitter.com/yourhandle) (如适用)

## 📄 许可证

MIT 许可证 - 创造令人惊叹的东西！🎉

有关完整详情，请参见 [LICENSE](LICENSE) 文件。

---

### 语言版本
- [English](README.md)
- [简体中文](README_zh-CN.md)
- [繁體中文](README_zh-TW.md)