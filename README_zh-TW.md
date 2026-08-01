# Typeless

macOS 按住即說。任意 App 中說話，端側 Whisper 轉寫並寫入目前輸入框。

[English](README.md) · [简体中文](README_zh-CN.md) · [繁體中文](README_zh-TW.md)

## 功能

- 全域按住快捷鍵（預設 **⌘⇧D**）→ 說話 → 鬆開 → 自動填入
- 純端側（WhisperKit / Core ML）；網路僅用於下載模型
- 模型：small / medium（預設）/ large-v3
- 本機歷史、麥克風選擇、選單列常駐（無 Dock 圖示）

## 安裝

1. 從 [Releases](https://github.com/jaydennleemc/Typelesss/releases) 下載
2. 移到「應用程式」並啟動
3. 允許 **麥克風** 與 **輔助使用**（快捷鍵 + 向其他 App 插入文字）

首次啟動可能下載預設 **medium** 模型（約 1.5 GB）。

## 使用

| | |
|---|---|
| 口述 | 按住 **⌘⇧D**，說話，鬆開 |
| 設定 | 選單列 → Settings…（**⌘,**） |
| 歷史 | 選單列 → History（**⌘Y**） |

## 建置

```bash
git clone https://github.com/jaydennleemc/Typelesss.git
open Typeless.xcodeproj   # 或 ./test-build.sh
```

macOS 15.5+，完整 Xcode。協作說明見 [AGENTS.md](AGENTS.md)。
