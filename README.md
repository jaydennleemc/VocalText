# VocalText

VocalText is a personal macOS menu bar utility that transforms your spoken words into text in real-time. Designed as a private tool for individual use, it resides unobtrusively in your menu bar and provides instant access to voice-to-text capabilities without sharing your data with anyone.

## 语言版本 Language Versions

- [English](README.md) (当前版本/Current version)
- [简体中文](README_zh-CN.md)
- [繁體中文](README_zh-TW.md)

## Personal Use Focus

VocalText was created as a personal productivity tool for individual users who need quick, private transcription capabilities. It's designed for:

- Personal note-taking during meetings, lectures, or brainstorming sessions
- Capturing ideas while commuting, exercising, or in quiet moments
- Creating text content without typing - perfect for when you're on the go
- Maintaining complete privacy of your spoken content

This tool does not support:
- Multi-user collaboration or shared workspaces
- Cloud synchronization between devices
- Team-based features or shared transcriptions
- Public sharing of transcribed content

## Technical Foundation

- **SwiftUI**: Modern interface framework for macOS
- **AVFoundation**: Apple's audio recording and processing framework
- **WhisperKit**: On-device machine learning framework for speech recognition
- **CoreAudio**: Low-level audio processing capabilities

## Key Features

- **Instant Personal Access**: One-click recording from your menu bar
- **Complete Privacy**: All processing happens locally on your device
- **Real-time Visualization**: iOS-style waveform display during recording
- **Multiple Language Support**: Works with various languages including English, Chinese, Spanish, French, etc.
- **Adjustable Quality**: Choose from different processing models (Tiny, Base, Small, Medium)
- **Personal Device Selection**: Support for your preferred audio input devices
- **Smart Formatting**: Automatic punctuation and formatting
- **Quick Clipboard Integration**: Copy your transcriptions with a single click

## How to Use

1. **Personal Setup**:
   - Click the waveform icon in your macOS menu bar
   - Press the large microphone button to begin recording
   - Speak clearly into your microphone
   - Press the stop button when finished
   - Your personal transcribed text appears instantly

2. **Private Workflow**:
   - Copy transcribed text by clicking on it or right-clicking for menu options
   - Adjust settings through the gear icon (language, model, audio device)
   - Access tutorial anytime through the help menu

## Ideal Personal Applications

- **Individual Meetings**: Capture your own meeting notes without interrupting discussions
- **Personal Interviews**: Transcribe one-on-one conversations for your records
- **Solo Lectures**: Record important points from educational sessions for personal study
- **Private Ideation**: Capture thoughts quickly while commuting or exercising
- **Personal Accessibility**: Assist yourself when typing is challenging

## Future Personal Enhancements

### Current Limitations
- macOS only
- Initial model download required (one-time setup)
- Single speaker optimization

### Upcoming Improvements
- **Enhanced Audio Processing**: Better performance in various personal environments
- **Export Capabilities**: Save your personal transcriptions in various formats
- **Text Editing**: Basic editing features within the tool for your transcriptions
- **Custom Shortcuts**: Keyboard shortcuts for faster personal access
- **Continuous Mode**: Background transcription for ongoing personal recordings

## Privacy Commitment

As a personal tool, VocalText prioritizes your individual privacy:
- Your audio never leaves your device
- No internet connection required for transcription
- No data collection or tracking of your personal information
- Models stored locally and encrypted on your device
- No sharing of your transcriptions with anyone

## Getting Help

For support with this personal tool:
1. Check GitHub issues for known solutions
2. Submit a detailed issue report if you encounter problems
3. Include your macOS version and error details for faster assistance

## License

This personal utility is released under the MIT License. See the LICENSE file for complete details.