# Typeless - AI Agent Instructions

You are an AI coding assistant helping with **Typeless**, a macOS menu bar app for real-time voice-to-text transcription using WhisperKit.

## Project Overview

- **Name**: Typeless (also referenced as VocalText in some files)
- **Platform**: macOS 15.5+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI + AppKit (menu bar)
- **Architecture**: MVVM with `@MainActor` for UI consistency
- **Key Dependencies**: WhisperKit, AVFoundation, CoreAudio

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Language** | Swift 5.9+ | Primary programming language |
| **UI Framework** | SwiftUI + AppKit | Modern declarative UI with macOS menu bar integration |
| **Concurrency** | Swift async/await + @MainActor | Asynchronous operations with thread safety |
| **Audio Recording** | AVFoundation (AVAudioEngine) | Low-level audio capture and processing |
| **Audio Devices** | CoreAudio | Hardware audio device enumeration and selection |
| **ML Inference** | WhisperKit (argmaxinc) | On-device speech-to-text transcription |
| **Model Format** | Core ML (.mlmodelc) | Apple-optimized ML model format |
| **Persistence** | UserDefaults | User preferences and settings storage |
| **Localization** | String Catalogs (.strings) | Multi-language support (en, zh-Hans, zh-Hant) |
| **Permissions** | App Sandbox + Entitlements | Secure macOS app containerization |
| **Notifications** | NotificationCenter | Cross-component communication |
| **Build System** | Xcode 15+ | IDE and build toolchain |

### Dependencies

```swift
// Core frameworks
import SwiftUI      // UI layer
import AppKit       // macOS-specific UI (NSStatusBar, NSPopover)
import AVFoundation // Audio recording and processing
import CoreAudio    // Audio device management

// Third-party
import WhisperKit   // On-device transcription (Swift Package Manager)
```

## Architecture

### MVVM Pattern

The app follows **MVVM (Model-View-ViewModel)** architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                        View Layer                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ MainView     │ │ SettingsView │ │ TutorialView         │ │
│  │ (SwiftUI)    │ │ (SwiftUI)    │ │ (SwiftUI)            │ │
│  └──────┬───────┘ └──────┬───────┘ └──────────┬───────────┘ │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
          │ @StateObject   │ @EnvironmentObject │
          │                │                    │
          ▼                ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                     ViewModel Layer                         │
│              (ObservableObject + @MainActor)                │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ AudioTranscriber                                        ││
│  │ - Recording state management                            ││
│  │ - Audio processing pipeline                             ││
│  │ - Model download & management                           ││
│  │ - Transcription coordination                            ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │ SystemHealthChecker                                     ││
│  │ - System requirements validation                        ││
│  │ - Permission checks                                     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
          │
          │ Uses
          ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
│  ┌──────────────────┐  ┌──────────────────────────────────┐ │
│  │ MenuBarController│  │ KeyboardShortcutManager          │ │
│  │ - NSStatusItem   │  │ - Global hotkey monitoring       │ │
│  │ - NSPopover      │  │ - CMD+R, CMD+S, etc.             │ │
│  └──────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
          │
          │ Manages
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ WhisperKit   │  │ AVAudioEngine│  │ CoreAudio        │   │
│  │ Transcription│  │ Recording    │  │ Device Enumeration│   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action → MainView → AudioTranscriber → AVAudioEngine (Record)
                                              ↓
                                           Audio Data
                                              ↓
                                    WAV File Creation
                                              ↓
                                    WhisperKit.transcribe()
                                              ↓
                                    Transcription Result
                                              ↓
                                    Published Property Update
                                              ↓
                                    SwiftUI View Re-render
```

### Key Architectural Decisions

1. **@MainActor for UI Classes**
   - All ObservableObjects that update UI are `@MainActor`
   - Ensures thread-safe UI updates without manual DispatchQueue.main

2. **Delegate Pattern for Error Handling**
   - `AudioTranscriberDelegate` protocol for error propagation
   - Decouples error handling from business logic

3. **NotificationCenter for Cross-Component Communication**
   - Loose coupling between MenuBarController and MainView
   - Enables keyboard shortcuts to trigger view actions

4. **Service-Oriented Design**
   - `MenuBarController`: Manages app lifecycle and menu bar UI
   - `KeyboardShortcutManager`: Handles global hotkeys
   - `SystemHealthChecker`: Validates system requirements

## Project Structure

```
Typeless/
├── TypelessApp.swift          # App entry point, window-less configuration
├── MenuBarController.swift    # Menu bar icon and popover management
├── MainView.swift             # Main transcription UI (400x300 window)
├── AudioTranscriber.swift     # Core audio recording & transcription logic
├── SettingsView.swift         # Model, device, and language settings
├── TutorialView.swift         # Onboarding tutorial flow
├── KeyboardShortcutManager.swift  # Global keyboard shortcuts (CMD+R, etc.)
├── SystemHealthChecker.swift  # System requirements validation
├── Localizable.strings        # i18n (en, zh-Hans, zh-Hant)
└── Typeless.entitlements      # Sandboxing and permissions
```

## Development Guidelines

### Swift Concurrency

- **ALWAYS** use `@MainActor` for UI-updating classes
- AudioTranscriber is `@MainActor` - all published properties update on main thread
- Use `Task { @MainActor in }` for async UI updates
- Use `withCheckedContinuation` for bridging completion handlers to async/await

### Audio Handling

```swift
// Correct pattern - check permissions before recording
if !hasMicrophonePermission {
    requestMicrophonePermission()
    return
}

// Use AVAudioEngine for recording
let inputNode = audioEngine.inputNode
let inputFormat = inputNode.outputFormat(forBus: 0)

// Always clean up taps when stopping
audioEngine.inputNode.removeTap(onBus: 0)
audioEngine.stop()
```

### Error Handling

Use the custom `TypelessError` enum for all errors:

```swift
enum TypelessError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case modelDownloadFailed(reason: String)
    case transcriptionFailed(reason: String)
    // ... see MainView.swift for full list
}
```

Report errors via delegate pattern:
```swift
delegate?.audioTranscriber(self, didEncounterError: .audioDeviceUnavailable)
```

### Memory Management

- Use `[weak self]` in all closures
- Implement thorough `deinit` cleanup
- Stop all timers (`Timer.invalidate()`)
- Remove NotificationCenter observers
- Clean up temporary files
- Remove audio engine taps before releasing

### Localization

- **ALL** user-facing strings use `NSLocalizedString()`
- Keys follow pattern: `module.element.description`
- Available languages: English (en), Simplified Chinese (zh-Hans), Traditional Chinese (zh-Hant)
- See `en.lproj/Localizable.strings` for reference

### SwiftUI Best Practices

```swift
// Use @StateObject for view-owned observable objects
@StateObject private var audioTranscriber = AudioTranscriber()

// Use @EnvironmentObject for shared state
@EnvironmentObject var audioTranscriber: AudioTranscriber

// Use @AppStorage for UserDefaults-backed settings
@AppStorage("selectedLanguage") private var uiLanguage: String = "en"
```

## Menu Bar App Specifics

- App is `LSUIElement` (no dock icon)
- Uses `NSPopover` for main window
- Left-click: toggle popover
- Right-click: context menu
- Window size: 400x300 points

## Model Management

WhisperKit models are downloaded on-demand:
- **Tiny**: ~75MB (fastest, lowest accuracy)
- **Base**: ~150MB
- **Small**: ~480MB (recommended)
- **Medium**: ~1.5GB
- **Large-v3**: Largest, highest accuracy

Models stored in: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`

### Model Lifecycle

1. Check if model exists via `isModelAlreadyDownloaded(model:)`
2. Download via `WhisperKit.download()` with progress callback
3. Preload WhisperKit instance to reduce latency
4. Transcribe with `DecodingOptions(language:)`

## Notification Patterns

Use NotificationCenter for cross-component communication:

```swift
// Key notifications
Notification.Name("RecordingStarted")
Notification.Name("RecordingStopped")
Notification.Name("ModelChanged")
Notification.Name("ModelDownloadRequested")
Notification.Name("AudioDevicesChanged")
```

## Code Style

### Naming
- Functions: verbs/verb phrases (`startRecording`, `checkMicrophonePermission`)
- Variables: nouns (`audioTranscriber`, `selectedDeviceIndex`)
- Boolean properties: starts with `is`/`has` (`isRecording`, `hasMicrophonePermission`)

### Comments
- Use `// MARK: - ` for section headers
- Use `// MARK: - Properties`, `// MARK: - Lifecycle`, etc.
- Chinese comments OK for this project (mixed codebase)
- DEBUG-only logging wrapped in `#if DEBUG` blocks

### Access Control
- Use `private` for internal helpers
- Use `fileprivate` sparingly
- Mark delegate protocols as `weak` to avoid retain cycles

## Testing & Debugging

### Debug Features
Memory monitoring available in DEBUG builds:
```swift
#if DEBUG
startMemoryMonitoring()  // Logs every 5 seconds
#endif
```

### Build Configuration
- Use Xcode project: `Typeless.xcodeproj`
- Deployment target: macOS 15.5
- Sandbox enabled with audio-input entitlement

## Security & Privacy

- All transcription happens **on-device** (privacy-first)
- No network required after model download
- Sandboxed with minimal entitlements:
  - `device.audio-input`
  - `network.client` (for model download only)
  - `files.user-selected.read-only`

## Common Tasks

### Adding a New Language
1. Add to `languages` array in `SettingsView.swift`
2. Add localization keys to all `Localizable.strings` files
3. Update README.md language support list

### Adding a New Keyboard Shortcut
1. Add to `KeyboardShortcutManager.swift`
2. Update `handleKeyEvent()` method
3. Document in README.md

### Modifying Audio Processing
- Audio flows: `AVAudioEngine` → `installTap` → `Data` → WAV file → `WhisperKit.transcribe()`
- Sample rate: typically 44100 Hz or 48000 Hz
- Format: Float32 PCM converted to Int16 PCM
- WAV header: 44 bytes (see `createWAVHeader()`)

## Communication

- Use backticks for file names: `AudioTranscriber.swift`
- Use backticks for function names: `startRecording()`
- Cite code using: ```startLine:endLine:filepath
- Be concise - provide code examples, not lengthy explanations

## Tool Usage

### When Exploring Code
- Use Grep for searching patterns across files
- Use Read for examining specific files
- Use Glob for finding files by pattern

### When Making Changes
- Read entire file first to understand context
- Match existing code style
- Use Edit tool for precise replacements
- Verify with `lsp_diagnostics` if available

### When Building
- Build via Xcode: `⌘+R` or `⌘+B`
- Use `test-build.sh` for automated builds
- Check build logs for errors

## References

- [WhisperKit Documentation](https://github.com/argmaxinc/WhisperKit)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [AVFoundation Audio](https://developer.apple.com/documentation/avfaudio)
- [macOS Menu Bar Apps](https://developer.apple.com/documentation/appkit/nsstatusbar)
