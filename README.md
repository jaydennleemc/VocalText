# VocalText 🎙️
> Real-time voice-to-text transcription for macOS - Privacy-first, offline capable

[![](https://img.shields.io/badge/platform-macOS-blue)](https://www.apple.com/macos)
[![](https://img.shields.io/badge/language-Swift-orange)](https://swift.org)
[![](https://img.shields.io/github/license/jaydennleemc/VocalText)](LICENSE)
[![](https://img.shields.io/github/v/release/jaydennleemc/VocalText)](https://github.com/jaydennleemc/VocalText/releases)

Transform your spoken words into text instantly with VocalText - the privacy-focused macOS menu bar app that works completely offline. Perfect for note-taking, interviews, lectures, and capturing ideas on the go!

## 🌟 FEATURES

- 🕵️‍♂️ **100% Private** - All processing happens on your device, no data leaves your Mac
- ⚡ **Real-time Transcription** - See your words appear as you speak
- 📶 **Offline First** - Works without internet connection after initial setup
- 🎛️ **Multi-language Support** - Transcribe in English, Chinese, Spanish, French, and 90+ languages
- 📊 **Live Visualization** - iOS-style waveform display during recording
- 🎛️ **Quality Options** - Choose from Tiny, Base, Small, or Medium models
- 🎧 **Audio Device Selection** - Use any connected microphone or audio input
- 📋 **One-click Copy** - Copy transcribed text to clipboard instantly
- 🎨 **Minimal Design** - Lives quietly in your menu bar

## 🚀 QUICK START

### Installation
1. Download the latest release from [Releases](https://github.com/jaydennleemc/VocalText/releases)
2. Extract the `.zip` file
3. Drag `VocalText.app` to your Applications folder
4. Launch the app and follow the first-time setup

### First Use
```bash
# On first launch, VocalText will:
# 1. Guide you through a quick tutorial
# 2. Download the default transcription model (~300MB)
# 3. Request microphone access permission
```

### Daily Usage
1. Click the waveform icon in your macOS menu bar
2. Press the large microphone button to start recording
3. Speak clearly - see real-time waveform visualization
4. Press the stop button when finished
5. Click on the transcribed text to copy to clipboard

## 🛠️ COMMANDS & USAGE

### Basic Workflow
```bash
# Start recording
Click Menu Bar Icon → Click Large Microphone Button

# Stop recording
Click Red Stop Button

# Copy text
Click on transcribed text → Automatically copied to clipboard
```

### Settings Access
```bash
# Open settings
Click Gear Icon in main window

# Available settings:
# - Model Selection (Tiny, Base, Small, Medium)
# - Audio Device Selection
# - Language Selection
```

### Model Options
| Model | Size | Accuracy | Speed | Best For |
|-------|------|----------|-------|----------|
| Tiny | ~75MB | Low | Fast | Quick notes, low accuracy needs |
| Base | ~150MB | Medium | Medium | General purpose transcription |
| Small | ~480MB | High | Slow | Most use cases, good balance |
| Medium | ~1.5GB | Very High | Very Slow | Professional transcription |

## 🧠 TECH STACK

- **SwiftUI** - Modern, declarative UI framework
- **AVFoundation** - Apple's audio recording and processing framework
- **WhisperKit** - On-device speech recognition framework
- **CoreAudio** - Low-level audio processing capabilities
- **AppKit** - macOS application foundation

## 🔧 ADVANCED USAGE

### Custom Audio Devices
- VocalText automatically detects connected audio devices
- Select your preferred input device in Settings
- Perfect for professional microphones or audio interfaces

### Language Selection
- Over 90 languages supported
- Change language in Settings
- Model automatically adapts to selected language

### Quality vs. Speed Tradeoff
- Smaller models (Tiny, Base) = faster processing, lower accuracy
- Larger models (Small, Medium) = slower processing, higher accuracy
- Choose based on your needs: quick notes vs. professional transcription

## 🛡️ PRIVACY & SECURITY

### Your Data Stays Private
- 🔒 No audio data leaves your device
- 🔒 No internet required for transcription
- 🔒 No user tracking or analytics
- 🔒 Models stored encrypted on your device
- 🔒 Open source - verify the code yourself

### Permissions
- **Microphone Access** - Only used for recording when you press the record button
- **Accessibility Features** - Optional, for enhanced clipboard integration

## 💰 PRICING

### Completely Free
- 💸 No subscription fees
- 💸 No premium features
- 💸 No hidden costs
- 💸 Open source and free forever

### One-time Costs
- Initial model download (~300MB-1.5GB depending on chosen model)
- Standard internet data rates apply for downloads

## 🤝 CONTRIBUTING

Love VocalText? Help make it even better!

### Ways to Contribute
- 🐛 Report bugs by creating [Issues](https://github.com/jaydennleemc/VocalText/issues)
- 💡 Suggest features by creating [Issues](https://github.com/jaydennleemc/VocalText/issues)
- 📝 Improve documentation by submitting PRs
- 🔧 Submit code improvements via [Pull Requests](https://github.com/jaydennleemc/VocalText/pulls)
- ⭐ Star this repo to show your support

### Development Setup
```bash
# Clone the repository
git clone https://github.com/jaydennleemc/VocalText.git

# Open in Xcode
open VocalText.xcodeproj

# Build and run
# CMD+R in Xcode
```

## 📚 LEARN MORE

### Related Resources
- [WhisperKit Documentation](https://github.com/argmaxinc/WhisperKit)
- [Apple AVFoundation Guide](https://developer.apple.com/av-foundation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

### Community
- [GitHub Discussions](https://github.com/jaydennleemc/VocalText/discussions)
- [Twitter](https://twitter.com/yourhandle) (if applicable)

## 📄 LICENSE

MIT License - build amazing things! 🎉

See [LICENSE](LICENSE) file for complete details.

---

### Language Versions
- [English](README.md)
- [简体中文](README_zh-CN.md)
- [繁體中文](README_zh-TW.md)