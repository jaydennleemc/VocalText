# Typeless

macOS 按住即说。任意应用中说话，端侧 Whisper 转写并写入当前输入框。

[English](README.md) · [简体中文](README_zh-CN.md) · [繁體中文](README_zh-TW.md)

## 功能

- 全局按住快捷键（默认 **⌘⇧D**）→ 说话 → 松手 → 自动填入
- 纯端侧（WhisperKit / Core ML）；网络仅用于下载模型
- 模型：small / medium（默认）/ large-v3
- 本地历史、麦克风选择、菜单栏常驻（无 Dock 图标）

## 安装

1. 从 [Releases](https://github.com/jaydennleemc/Typelesss/releases) 下载
2. 移到「应用程序」并启动
3. 允许 **麦克风** 与 **辅助功能**（快捷键 + 向其他应用插入文字）

首次启动可能下载默认 **medium** 模型（约 1.5 GB）。

## 使用

| | |
|---|---|
| 口述 | 按住 **⌘⇧D**，说话，松开 |
| 设置 | 菜单栏 → Settings…（**⌘,**） |
| 历史 | 菜单栏 → History（**⌘Y**） |

## 构建

```bash
git clone https://github.com/jaydennleemc/Typelesss.git
open Typeless.xcodeproj   # 或 ./test-build.sh
```

macOS 15.5+，完整 Xcode。协作说明见 [AGENTS.md](AGENTS.md)。
