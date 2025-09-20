# VocalText 🎙️
> 適用於 macOS 的即時語音轉文字工具 - 注重隱私，支援離線使用

[![](https://img.shields.io/badge/平台-macOS-blue)](https://www.apple.com/macos)
[![](https://img.shields.io/badge/語言-Swift-orange)](https://swift.org)
[![](https://img.shields.io/github/license/jaydennleemc/VocalText)](LICENSE)
[![](https://img.shields.io/github/v/release/jaydennleemc/VocalText)](https://github.com/jaydennleemc/VocalText/releases)

透過 VocalText 即時將您的語音轉換為文字 - 這款注重隱私的 macOS 選單列應用可完全離線工作。非常適合做筆記、採訪、講座和隨時隨地捕捉想法！

## 🌟 功能特點

- 🕵️‍♂️ **100% 隱私保護** - 所有處理都在您的裝置上進行，資料不會離開您的 Mac
- ⚡ **即時轉錄** - 邊說邊看文字出現
- 📶 **離線優先** - 初始設定後無需網路連接即可工作
- 🎛️ **多語言支援** - 支援英語、中文、西班牙語、法語等 90 多種語言轉錄
- 📊 **即時可視化** - 錄製期間顯示 iOS 風格的波形圖
- 🎛️ **品質選項** - 可選擇 Tiny、Base、Small 或 Medium 模型
- 🎧 **音訊設備選擇** - 可使用任何連接的麥克風或音訊輸入設備
- 📋 **一鍵複製** - 瞬間將轉錄文字複製到剪貼簿
- 🎨 **極簡設計** - 安靜地駐留在您的選單列中

## 🚀 快速開始

### 安裝
1. 從 [發布頁面](https://github.com/jaydennleemc/VocalText/releases) 下載最新版本
2. 解壓 `.zip` 檔案
3. 將 `VocalText.app` 拖曳到您的應用程式資料夾
4. 啟動應用並按照首次設定操作

### 首次使用
```bash
# 首次啟動時，VocalText 將：
# 1. 引導您完成快速教學
# 2. 下載預設轉錄模型 (~300MB)
# 3. 請求麥克風存取權限
```

### 日常使用
1. 點擊 macOS 選單列中的波形圖示
2. 按下大麥克風按鈕開始錄製
3. 清晰地說話 - 檢視即時波形可視化
4. 完成後按下停止按鈕
5. 點擊轉錄文字將其複製到剪貼簿

## 🛠️ 命令和用法

### 基本工作流程
```bash
# 開始錄製
點擊選單列圖示 → 點擊大麥克風按鈕

# 停止錄製
點擊紅色停止按鈕

# 複製文字
點擊轉錄文字 → 自動複製到剪貼簿
```

### 存取設定
```bash
# 打開設定
點擊主視窗中的齒輪圖示

# 可用設定：
# - 模型選擇 (Tiny, Base, Small, Medium)
# - 音訊設備選擇
# - 語言選擇
```

### 模型選項
| 模型 | 大小 | 準確度 | 速度 | 最佳用途 |
|-------|------|----------|-------|----------|
| Tiny | ~75MB | 低 | 快 | 快速筆記，對準確度要求不高 |
| Base | ~150MB | 中 | 中 | 一般用途轉錄 |
| Small | ~480MB | 高 | 慢 | 大多數使用場景，平衡性好 |
| Medium | ~1.5GB | 很高 | 很慢 | 專業轉錄 |

## 🧠 技術棧

- **SwiftUI** - 現代化宣告式 UI 框架
- **AVFoundation** - Apple 音訊錄製和處理框架
- **WhisperKit** - 裝置端語音識別框架
- **CoreAudio** - 低階音訊處理功能
- **AppKit** - macOS 應用程式基礎

## 🔧 進階用法

### 自訂音訊設備
- VocalText 自動偵測連接的音訊設備
- 在設定中選擇您偏好的輸入設備
- 適合專業麥克風或音訊介面

### 語言選擇
- 支援 90 多種語言
- 在設定中更改語言
- 模型會自動適應所選語言

### 品質與速度權衡
- 較小模型 (Tiny, Base) = 處理速度快，準確度低
- 較大模型 (Small, Medium) = 處理速度慢，準確度高
- 根據您的需求選擇：快速筆記 vs 專業轉錄

## 🛡️ 隱私與安全

### 您的資料保持私密
- 🔒 沒有音訊資料會離開您的設備
- 🔒 轉錄無需網際網路連接
- 🔒 無使用者追蹤或分析
- 🔒 模型在您的設備上加密儲存
- 🔒 開源 - 您可以自行驗證程式碼

### 權限
- **麥克風存取** - 僅在您按下錄製按鈕時用於錄製
- **輔助功能** - 可選，用於增強剪貼簿整合

## 💰 價格

### 完全免費
- 💸 無訂閱費用
- 💸 無高級功能
- 💸 無隱藏成本
- 💸 開源且永久免費

### 一次性成本
- 初始模型下載 (~300MB-1.5GB，取決於所選模型)
- 下載時按標準網路資料費率計費

## 🤝 貢獻

喜歡 VocalText 嗎？幫助我們讓它變得更好！

### 貢獻方式
- 🐛 透過建立 [Issues](https://github.com/jaydennleemc/VocalText/issues) 報告錯誤
- 💡 透過建立 [Issues](https://github.com/jaydennleemc/VocalText/issues) 建議功能
- 📝 透過提交 PR 改進文件
- 🔧 透過 [Pull Requests](https://github.com/jaydennleemc/VocalText/pulls) 提交程式碼改進
- ⭐ 給這個倉庫加星以表示支持

### 開發設定
```bash
# 克隆倉庫
git clone https://github.com/jaydennleemc/VocalText.git

# 在 Xcode 中打開
open VocalText.xcodeproj

# 建置和執行
# 在 Xcode 中按 CMD+R
```

## 📚 了解更多

### 相關資源
- [WhisperKit 文件](https://github.com/argmaxinc/WhisperKit)
- [Apple AVFoundation 指南](https://developer.apple.com/av-foundation/)
- [SwiftUI 教學](https://developer.apple.com/tutorials/swiftui)

### 社群
- [GitHub 討論](https://github.com/jaydennleemc/VocalText/discussions)
- [Twitter](https://twitter.com/yourhandle) (如適用)

## 📄 授權

MIT 授權條款 - 創造令人驚艷的東西！🎉

有關完整詳情，請參見 [LICENSE](LICENSE) 檔案。

---

### 語言版本
- [English](README.md)
- [简体中文](README_zh-CN.md)
- [繁體中文](README_zh-TW.md)