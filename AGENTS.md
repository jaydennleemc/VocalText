# Typeless — AI Agent Instructions

You are an AI coding assistant working on **Typeless**, a privacy-first macOS menu bar app for on-device voice-to-text transcription via WhisperKit.

> `CLAUDE.md` and `QWEN.md` are symlinks to this file. Edit only `AGENTS.md`.

---

## Project Snapshot

| | |
|---|---|
| **Product** | Typeless (legacy name “VocalText” may appear in file headers) |
| **Platform** | macOS 15.5+ |
| **Language** | Swift 5 |
| **UI** | SwiftUI + AppKit (menu bar + `NSPopover`) |
| **Architecture** | MVVM + service layer; `@MainActor` for UI-facing types |
| **ML** | WhisperKit (SPM, `argmaxinc/WhisperKit`) → Core ML |
| **Persistence** | UserDefaults |
| **i18n** | `Localizable.strings` — `en`, `zh-Hans`, `zh-Hant` |
| **Bundle ID** | `com.jaydenlee.Typeless` |
| **Sandbox** | Yes — audio input, network client (model download), user-selected files RO |

**Privacy rule:** transcription is on-device. Network is only for model download.

---

## Repository Layout

```
Typelesss/                          # repo root (note triple-s)
├── AGENTS.md                       # this file (agent source of truth)
├── README.md / README_zh-*.md
├── test-build.sh                   # local xcodebuild Release
├── Typeless.xcodeproj/
├── Typeless/                       # app target
│   ├── TypelessApp.swift           # @main + AppDelegate
│   ├── MenuBarController.swift     # NSStatusItem + NSPopover + shortcut actions
│   ├── KeyboardShortcutManager.swift
│   ├── MainView.swift              # root SwiftUI chrome + navigation shell
│   ├── SettingsView.swift          # model / device / language / shortcuts
│   ├── TutorialView.swift
│   ├── Models/
│   │   ├── AudioDevice.swift       # AudioDeviceModel
│   │   └── TypelessError.swift     # TypelessError + ErrorType
│   ├── ViewModels/
│   │   └── AudioTranscriber.swift  # coordinator + singleton (nav / errors / quick-record)
│   ├── Services/
│   │   ├── AudioRecorder.swift     # AVAudioEngine capture
│   │   ├── TranscriptionService.swift
│   │   ├── ModelManager.swift      # download / preload WhisperKit
│   │   ├── DeviceManager.swift
│   │   ├── PermissionManager.swift
│   │   └── TranscriptionOverlayManager.swift  # floating quick-record overlay
│   ├── Views/                      # presentational components
│   ├── Extensions/Notifications.swift  # error notifications only
│   ├── en.lproj/ zh-Hans.lproj/ zh-Hant.lproj/
│   └── Typeless.entitlements
└── TypelessTests/
```

Root `en.lproj` / `zh-*.lproj` are symlinks into `Typeless/`.

---

## Architecture

### Layers

```
AppDelegate
  └─ MenuBarController          # status item, popover; calls AudioTranscriber.shared
       ├─ KeyboardShortcutManager
       ├─ TranscriptionOverlayManager
       └─ MainView (SwiftUI)
            └─ AudioTranscriber.shared   # @MainActor coordinator
                 ├─ AudioRecorder
                 ├─ ModelManager ── WhisperKit
                 ├─ TranscriptionService
                 ├─ DeviceManager
                 └─ PermissionManager
```

### Roles

| Type | Role |
|------|------|
| `AudioTranscriber` | Single coordinator. Owns services, navigation, error banner, quick-record. Forwards service `@Published` via Combine. `static let shared`. |
| Services | Single-responsibility, mostly `@MainActor` + `ObservableObject`. No UI. |
| Views | SwiftUI only. Bind to `AudioTranscriber` / `@AppStorage`; no AVFoundation or WhisperKit. |
| `MenuBarController` | AppKit shell: menu bar, popover lifecycle; direct method calls into `AudioTranscriber.shared`. |

### Primary data flow

```
User (button / ⌘R / hold quick-record)
  → AudioTranscriber.startRecording() / beginQuickRecord()
  → PermissionManager + DeviceManager gates
  → AudioRecorder (AVAudioEngine tap → Float32 buffer)
  → stop → temp WAV via AVAudioFile
  → ModelManager.getWhisperKit()
  → TranscriptionService.transcribe(path, whisperKit)
  → @Published transcript → SwiftUI re-render
  → (quick record) auto-copy + TranscriptionOverlayManager
```

### Cross-component communication

1. **Direct calls** — Keyboard shortcuts → `MenuBarController` → `AudioTranscriber.shared` methods. Prefer this over notifications.
2. **NotificationCenter** — only for service → coordinator errors: `.modelErrorOccurred`, `.transcriptionError` (object: `TypelessError`). Defined in `Extensions/Notifications.swift`.
3. **Combine** — `AudioTranscriber` binds service publishers with `.assign(to: &$…)`.

Do **not** reintroduce a parallel AppState, MainViewDelegate, or notification bus for UI actions.

---

## Key Features (behavioral)

### Menu bar UX

- `LSUIElement` — no Dock icon.
- Left-click status item → toggle `NSPopover` (hosting `MainView`).
- Right-click → context menu (Quit).
- Window size: **400×340** (tutorial **380** height).

### Recording modes

1. **Popover record** — large mic button in main UI; start/stop; result shown in card; click to copy.
2. **Quick record** — global hold shortcut (default `cmd+shift+v`, key `QuickRecordShortcutKey`). Shows floating overlay near cursor via `TranscriptionOverlayManager`; auto-copy on success.

### Models (WhisperKit)

| Variant | Approx. size | Notes |
|---------|--------------|--------|
| tiny | ~75MB | Default |
| base | ~150MB | |
| small | ~480MB | Good accuracy/speed balance |
| medium | ~1.5GB | Highest quality in app UI |
| large-v3 | ~3GB | Largest option in settings |

Storage path: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`

Lifecycle: `isModelAlreadyDownloaded` (checks required `.mlmodelc` + `Config.json`) → `WhisperKit.download` → `preloadWhisperKit()` → reuse instance.

Optional first-launch: `AppDelegate.copyPreDownloadedModelsIfNeeded()` copies bundled models if present.

### Global shortcuts (`KeyboardShortcutManager`)

| Shortcut | Action |
|----------|--------|
| ⌘R | Toggle recording |
| ⌥⌘R | Force retry model download |
| ⌘C | Copy transcript |
| ⌘S / ⌘, | Open settings |
| ⌘W | Close popover |
| ⌘T | Show tutorial |
| Configurable hold (default ⌘⇧V) | Quick record (keyDown start / keyUp stop) |

Global monitors need Accessibility permission for some environments; settings UI includes accessibility guidance.

---

## Development Rules

### Concurrency & threading

- UI-facing `ObservableObject`s: `@MainActor`.
- Audio engine callbacks may leave the main actor — hop back with `Task { @MainActor in … }` for published updates.
- Use `[weak self]` in closures and Notification observers.
- Clean up: cancel Combine bags, `Timer.invalidate()`, remove audio taps, remove observers, delete temp WAV files.

### Errors

- Use `TypelessError` (`Models/TypelessError.swift`) for all user-facing failures.
- Surface via `AudioTranscriber.showError` → `ErrorBanner` in `MainView`.
- Prefer `TypelessError` properties: `type` (warning/error/info), `isRecoverable`.

### Localization

- **All** user-visible strings: `NSLocalizedString("key", comment:)`.
- Key style: `module.element.description` (e.g. `error.audio.permissionDenied`).
- Update **all three** catalogs under `Typeless/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`.

### SwiftUI patterns

```swift
@StateObject / shared AudioTranscriber.shared for cross-window access
@EnvironmentObject when injected
@AppStorage("selectedLanguage") for UI language prefs
```

Navigation: `AudioTranscriber.navigation` → `.main | .settings | .tutorial`.

### Memory & resources

- Cap recording buffer (~100MB in `AudioRecorder`).
- Always `removeTap` + `stop` engine on stop/failure.
- Temp files under `FileManager.default.temporaryDirectory` — delete in `defer`.

### Access control & style

- `// MARK: -` section headers.
- Functions: verb phrases; booleans: `is` / `has` prefixes.
- `private` by default.
- Mixed EN/ZH comments are OK; DEBUG logs only inside `#if DEBUG`.
- Prefer small presentational views under `Views/` over growing `MainView` / `SettingsView` further.
- Keep the stack lean: no parallel state objects, unused design-token catalogs, or pass-through notification buses.

---

## Important Files Cheat Sheet

| Task | Start here |
|------|------------|
| Record pipeline | `Services/AudioRecorder.swift`, `ViewModels/AudioTranscriber.swift` |
| Transcription | `Services/TranscriptionService.swift`, `Services/ModelManager.swift` |
| Model download/path | `ModelManager.swift` |
| Devices | `Services/DeviceManager.swift`, `Models/AudioDevice.swift` |
| Permissions | `Services/PermissionManager.swift` |
| Menu bar / popover | `MenuBarController.swift` |
| Shortcuts | `KeyboardShortcutManager.swift` |
| Floating overlay | `TranscriptionOverlayManager.swift` |
| Errors | `Models/TypelessError.swift` |
| Notifications | `Extensions/Notifications.swift` |
| Tests | `TypelessTests/` |

---

## Common Tasks

### Add a UI language (app chrome)

1. Add keys to all three `Localizable.strings`.
2. Wire UI language picker in `SettingsView` if needed.
3. `MenuBarController.updateLocale()` already reacts to UserDefaults.

### Add a speech language for Whisper

1. Add option in `SettingsView` language list.
2. Persist selection; call `AudioTranscriber.setLanguage` → `TranscriptionService.setLanguage`.
3. Pass via `DecodingOptions(language:)` (already wired).

### Add a keyboard shortcut

1. Handle in `KeyboardShortcutManager.handleKeyEvent` (and keyUp if hold-based).
2. Call a method on `MenuBarController` that hits `AudioTranscriber.shared` (or the overlay).
3. Document in README if user-facing.

### Change audio format / WAV path

1. Capture: `AudioRecorder` (Float32 from engine).
2. Write: `AudioTranscriber.processAudio` uses `AVAudioFile` for temp WAV.
3. Sample rate comes from the input format (default fallback 44100 mono).

### Add a notification

Only if you truly need service → coordinator fan-out. Prefer method calls.
1. Add `static let …` on `Notification.Name` in `Extensions/Notifications.swift`.
2. Post with `.name` syntax only.

---

## Build, Test, Debug

```bash
# Open in Xcode
open Typeless.xcodeproj

# Scripted Release build (requires full Xcode, not CLT-only)
./test-build.sh

# Unit tests
xcodebuild test -project Typeless.xcodeproj -scheme Typeless -destination 'platform=macOS'
```

- Scheme: **Typeless**
- Deployment target: **macOS 15.5**
- Do not commit DerivedData, `.build`, or user xcuserdata.

---

## Security & Entitlements

`Typeless.entitlements`:

- `com.apple.security.app-sandbox`
- `com.apple.security.device.audio-input`
- `com.apple.security.network.client` — model download only
- `com.apple.security.files.user-selected.read-only`

Never expand network/file entitlements without a clear product need. Do not send audio or transcripts off-device.

---

## Agent Workflow

1. **Explore** with Grep/Read; match existing style before editing.
2. **Prefer surgical edits** over large rewrites of `SettingsView` / `MainView`.
3. **Respect layers**: Views → ViewModels → Services → system frameworks.
4. **No new third-party deps** unless agreed; WhisperKit is the only SPM product.
5. **After behavior changes**, run `./test-build.sh` or Xcode build; run `TypelessTests` when touching models/errors.
6. **Cite code** as `startLine:endLine:path` when explaining.
7. Stay concise: concrete diffs and examples over long essays.
8. **YAGNI**: do not reintroduce AppState, design-token files, or notification buses for single-caller actions.

### Known debt / pitfalls

- `SettingsView.swift` is still large (~700 lines) with local button styles.
- File headers may still say “VocalText”.
- `SettingsView` / `KeyboardShortcutManager` share `QuickRecordShortcutKey` + `QuickRecordShortcutEnabled` UserDefaults keys — keep them in sync.

---

## References

- [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)
