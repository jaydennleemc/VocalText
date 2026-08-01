# Typeless — AI Agent Instructions

You are an AI coding assistant working on **Typeless**, a privacy-first macOS menu bar app for on-device voice dictation via WhisperKit (Core ML).

> `CLAUDE.md` and `QWEN.md` are symlinks to this file. Edit only `AGENTS.md`.

---

## Project Snapshot

| | |
|---|---|
| **Product** | Typeless (legacy “VocalText” may still appear in some file headers) |
| **Platform** | macOS 15.5+ |
| **Language** | Swift 5 |
| **UI** | AppKit shell (status item + menu + floating HUD + `NSWindow`) + SwiftUI content views |
| **Architecture** | MVVM + service layer; `@MainActor` for UI-facing types |
| **ML** | WhisperKit (SPM, `argmaxinc/WhisperKit`) → Core ML |
| **Persistence** | UserDefaults (prefs); JSON under Application Support (history) |
| **i18n** | `Localizable.strings` — `en`, `zh-Hans`, `zh-Hant` |
| **Bundle ID** | `com.jaydenlee.Typeless` |
| **Version** | 1.0.1 (CFBundleVersion 2) |
| **Sandbox** | **Release:** yes. **Debug:** sandbox off (`Typeless.debug.entitlements`) so Carbon hotkeys + Accessibility work under Xcode |

**Privacy rule:** transcription is on-device. Network is only for WhisperKit model download. Never send audio or transcripts off-device.

**Product model:** IME-style hold-to-dictate — **not** a popover mini-app. Primary loop is global hold shortcut → record → release → transcribe → auto-insert into the focused field. Menu “Start/Stop Dictating” is the same pipeline without the hotkey.

---

## Repository Layout

```
Typelesss/                          # repo root (note triple-s)
├── AGENTS.md                       # this file (agent source of truth)
├── README.md / README_zh-*.md
├── test-build.sh                   # local xcodebuild Release
├── Typeless.xcodeproj/
├── Typeless/                       # app target
│   ├── TypelessApp.swift           # @main AppKit entry + AppDelegate
│   ├── MenuBarController.swift     # NSStatusItem + NSMenu; owns overlay lifecycle
│   ├── KeyboardShortcutManager.swift  # Carbon hold-to-dictate + session state
│   ├── AppWindows.swift            # Settings / History NSWindows (LSUIElement)
│   ├── SettingsView.swift          # model / speech / UI language / device / shortcut / AX
│   ├── Models/
│   │   ├── AudioDevice.swift
│   │   ├── RecordingEntry.swift    # history row (Codable)
│   │   └── TypelessError.swift
│   ├── ViewModels/
│   │   └── AudioTranscriber.swift  # coordinator + singleton
│   ├── Services/
│   │   ├── AudioRecorder.swift     # AVCaptureSession → Float32 PCM
│   │   ├── TranscriptionService.swift
│   │   ├── ModelManager.swift
│   │   ├── DeviceManager.swift
│   │   ├── PermissionManager.swift
│   │   ├── AccessibilityAuth.swift
│   │   ├── TextInserter.swift      # AX caret insert → synthetic ⌘V → clipboard
│   │   ├── HistoryStore.swift      # local JSON history (cap 150)
│   │   └── TranscriptionOverlayManager.swift  # floating dictate HUD
│   ├── Views/
│   │   └── HistoryView.swift
│   ├── en.lproj/ zh-Hans.lproj/ zh-Hant.lproj/
│   ├── Typeless.entitlements       # Release (sandboxed)
│   └── Typeless.debug.entitlements # Debug (sandbox off)
└── TypelessTests/
```

Root `en.lproj` / `zh-*.lproj` are symlinks into `Typeless/`.

There is **no** `MainView` / popover shell / tutorial flow. Do not reintroduce them without an explicit product decision.

---

## Architecture

### Layers

```
TypelessMain.main()                 # pure AppKit @main (no SwiftUI App / Settings scene)
  └─ AppDelegate
       └─ MenuBarController         # status item + NSMenu
            ├─ KeyboardShortcutManager   # Carbon press + hold-poll; session flags
            ├─ TranscriptionOverlayManager
            └─ AppWindows                # Settings / History NSWindows
                 └─ SettingsView / HistoryView (SwiftUI)

AudioTranscriber.shared             # @MainActor coordinator
  ├─ AudioRecorder
  ├─ ModelManager ── WhisperKit
  ├─ TranscriptionService
  ├─ DeviceManager
  ├─ PermissionManager
  ├─ HistoryStore.shared            # written after successful transcript
  └─ TextInserter                   # quick-record commit path
```

### Roles

| Type | Role |
|------|------|
| `AudioTranscriber` | Single coordinator. Owns services, quick-record session, model/language proxies, `lastErrorMessage`. Forwards service `@Published` via Combine. `static let shared`. |
| Services | Single-responsibility, mostly `@MainActor` + `ObservableObject` (or pure enums for helpers). No UI. |
| Views | SwiftUI only (`SettingsView`, `HistoryView`). Bind to `AudioTranscriber` / `@AppStorage` / `HistoryStore`. No AVFoundation or WhisperKit. |
| `MenuBarController` | AppKit shell: status item, menu actions, overlay lifecycle; calls into `AudioTranscriber.shared`. |
| `KeyboardShortcutManager` | Carbon hotkey + hold-poll; **session state machine** shared with menu toggle. |
| `AppWindows` | Hosts Settings and History as real `NSWindow`s. Do not rely on SwiftUI `Settings` scene for agent apps. |

### Dictate session (one state machine)

Both Carbon hold and menu toggle share the same audio path (`startQuickRecord` / `stopQuickRecord`). Session flags live only in `KeyboardShortcutManager`:

| Entry | Start | End |
|-------|--------|-----|
| **Hold (Carbon)** | `beginHoldSession()` (private) + hold-poll → `startQuickRecord()` | poll detects release → `endSession()` + `stopQuickRecord()` |
| **Menu toggle** | `beginMenuSession()` (no poll) + `startQuickRecord()` | `endSession()` + `stopQuickRecord()` |

- `isQuickRecordInProgress` blocks Carbon double-start while menu session is active.
- Menu sessions **must not** start hold-poll (keys are not held → would auto-stop ~0.6s later).
- Do **not** reintroduce parallel `forceBeginDictateFlag` / `forceEndDictateFlag` APIs.

### Primary data flow (quick dictate)

```
User holds global shortcut (default ⌘⇧D)
  → KeyboardShortcutManager (Carbon press + hold poll)
  → MenuBarController.startQuickRecord()
  → AudioTranscriber.beginQuickRecord()
  → PermissionManager + DeviceManager gates
  → AudioRecorder (AVCaptureSession → Float32 PCM)
  → TranscriptionOverlayManager shows HUD near cursor
User releases shortcut (or menu Stop)
  → endQuickRecord() → stop capture
  → write 16 kHz mono peak-normalized temp WAV
  → ModelManager.ensureWhisperKit()
  → TranscriptionService.transcribe (language, then auto-detect fallback)
  → HistoryStore.add(...)
  → TextInserter.insert (AX selected text → ⌘V → clipboard always)
  → overlay shows result, then dismisses
```

### Cross-component communication

1. **Direct calls** — shortcuts / menu → `MenuBarController` → `AudioTranscriber.shared`. Prefer this over notifications.
2. **NotificationCenter** — only Accessibility trust: `KeyboardShortcutManager` posts `.accessibilityTrustChanged` (Settings observes). No error notification bus.
3. **Combine** — `AudioTranscriber` binds service publishers with `.assign(to: &$…)`; menu bar icon/tooltip observe coordinator state.

Do **not** reintroduce a parallel AppState, popover host, or notification bus for UI actions.

---

## Key Features (behavioral)

### Menu bar UX

- `LSUIElement` + `NSApp.setActivationPolicy(.accessory)` — no Dock icon.
- Status item shows template SF Symbol (`waveform` / recording / loading states).
- **Click opens `NSMenu`** (not a popover): status, retry load, hold-hint, Start/Stop Dictating, Settings… (⌘,), History (⌘Y), Quit (⌘Q).
- Settings: `AppWindows.openSettings()` → ~520×400 window (`SettingsView`).
- History: `AppWindows.openHistory()` → ~380×360 window (`HistoryView`).
- App main menu (About / Settings… / Quit) is built in `KeyboardShortcutManager.setupAppMenuShortcuts()` — that is how ⌘, works (no empty SwiftUI `Settings` scene).

### Dictation modes

1. **Hold-to-dictate (primary)** — global shortcut (default `cmd+shift+d`, keys `QuickRecordShortcutKey` / `QuickRecordShortcutEnabled`). Carbon hotkey starts; poll timer ends when required modifiers are released. Floating HUD via `TranscriptionOverlayManager`. On success: auto-insert + history.
2. **Menu dictate** — same pipeline as toggle (start/stop), for diagnosis / no Accessibility.

> **Not streaming ASR.** Audio is captured while held, then transcribed as a whole after release. Waveform in the HUD is live level only.

### Auto-insert (`TextInserter`)

Preference order:

1. Accessibility `kAXSelectedTextAttribute` on focused element (insert at caret).
2. Clipboard + synthetic ⌘V (needs Accessibility for `CGEvent`).
3. Always leave text on the general pasteboard as fallback.

Requires Accessibility trust (`AccessibilityAuth`). Settings UI guides the user; Debug builds run unsandboxed so AX/hotkeys work from DerivedData.

### History

- `HistoryStore.shared` — JSON file: `~/Library/Application Support/Typeless/transcription_history.json`
- Cap **150** entries; newest first.
- Model: `RecordingEntry` (id, date, duration, transcript, language, model).

### Models (WhisperKit)

| Variant | Approx. size | Notes |
|---------|--------------|--------|
| small | ~480 MB | Lowest tier still offered |
| medium | ~1.5 GB | **Default**; unknown/legacy names clamp here |
| large-v3 | ~3 GB | Highest quality in UI |

- Allowed set is hard-coded in `ModelManager` / `SettingsView`: `small`, `medium`, `large-v3`.
- Storage: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`
- Lifecycle: `isModelAlreadyDownloaded` (required `.mlmodelc` dirs + `config.json`) → `WhisperKit.download` → `preloadWhisperKit()` / `prepareModelAtLaunch()` → reuse instance.
- Boot progress / status: `ModelManager.bootStatus` (also mirrored on `AudioTranscriber`).

### Speech languages (settings picker)

`zh`, `yue`, `en`, `ja`, `ko`, `fr`, `de`, `es` (default speech language `zh`). Empty results retry with Whisper language detection.

### Global shortcuts

| Shortcut | Action |
|----------|--------|
| Hold configurable combo (default **⌘⇧D**) | Quick dictate (press start / release stop) |
| ⌘, | Open Settings (status menu + app menu → `AppWindows`) |
| ⌘Y | Open History |
| ⌘Q | Quit |

Hold shortcut uses **Carbon** `RegisterEventHotKey` + release polling. Shared UserDefaults keys with Settings: `QuickRecordShortcutKey`, `QuickRecordShortcutEnabled`. Legacy `cmd+shift+v` is migrated to `cmd+shift+d` on launch. Display formatting: `ShortcutFormatting.display(_:)`.

---

## Development Rules

### Concurrency & threading

- UI-facing `ObservableObject`s: `@MainActor`.
- Capture callbacks may leave the main actor — hop back with `Task { @MainActor in … }` for published updates.
- Use `[weak self]` in closures and Notification observers.
- Clean up: cancel Combine bags, `Timer.invalidate()`, stop capture session, remove observers, delete temp WAV files.
- Stale transcription races: `processGeneration` in `AudioTranscriber` — bump on each stop; ignore outdated `processAudio` Tasks.

### Errors

- Use `TypelessError` for user-facing failures.
- Surface via `AudioTranscriber.showError` → `lastErrorMessage` (menu tooltip / DEBUG log). No error banner UI.
- Prefer `TypelessError.isRecoverable` when deciding whether to retry.

### Localization

- **All** user-visible strings: `NSLocalizedString("key", comment:)`.
- Key style: `module.element.description` (e.g. `error.audio.permissionDenied`).
- Update **all three** catalogs under `Typeless/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`.

### SwiftUI / AppKit patterns

```swift
AudioTranscriber.shared          // cross-window coordinator
@EnvironmentObject when injected
@AppStorage("selectedLanguage")  // UI chrome language
AppWindows.openSettings()        // never rely on showSettingsWindow: for agent apps
// Entry is pure AppKit @main — do not re-add SwiftUI App + empty Settings scene
```

### Memory & resources

- Cap recording buffer (~100 MB in `AudioRecorder`).
- Always stop capture session cleanly on stop/failure.
- Temp WAV under `FileManager.default.temporaryDirectory` — delete in `defer`.
- Resample/peak-normalize to **16 kHz mono** before Whisper (see `AudioTranscriber.writeWAV`).

### Access control & style

- `// MARK: -` section headers.
- Functions: verb phrases; booleans: `is` / `has` prefixes.
- `private` by default.
- Mixed EN/ZH comments are OK; DEBUG logs only inside `#if DEBUG`.
- Prefer small presentational views under `Views/` over growing `SettingsView` further.
- Keep the stack lean: no parallel state objects, design-token catalogs, popover shells, or notification buses for single-caller actions.

---

## Important Files Cheat Sheet

| Task | Start here |
|------|------------|
| Record / dictate pipeline | `ViewModels/AudioTranscriber.swift`, `Services/AudioRecorder.swift` |
| Transcription | `Services/TranscriptionService.swift`, `Services/ModelManager.swift` |
| Auto-insert into apps | `Services/TextInserter.swift`, `Services/AccessibilityAuth.swift` |
| History | `Services/HistoryStore.swift`, `Views/HistoryView.swift`, `Models/RecordingEntry.swift` |
| Menu bar shell | `MenuBarController.swift` |
| Hold shortcut + session | `KeyboardShortcutManager.swift` |
| Floating HUD | `TranscriptionOverlayManager.swift` |
| Settings / History windows | `AppWindows.swift`, `SettingsView.swift` |
| Devices / mic permission | `DeviceManager.swift`, `PermissionManager.swift` |
| Errors | `Models/TypelessError.swift` |
| App entry | `TypelessApp.swift` |
| Tests | `TypelessTests/` |

---

## Common Tasks

### Add a UI language (app chrome)

1. Add keys to all three `Localizable.strings`.
2. Wire UI language picker in `SettingsView` if needed.

### Add a speech language for Whisper

1. Add option in `SettingsView` `languages` list.
2. Persist `SelectedLanguage`; call `AudioTranscriber.setLanguage` → `TranscriptionService.setLanguage`.
3. Pass via `DecodingOptions(language:)` (already wired; empty-result auto-detect remains).

### Change the dictate hotkey

1. Persist `QuickRecordShortcutKey` / `QuickRecordShortcutEnabled` (Settings already does).
2. `KeyboardShortcutManager.installAll()` re-registers Carbon hotkey.
3. Keep Settings and manager defaults in sync (`cmd+shift+d`).

### Change audio capture / WAV path

1. Capture: `AudioRecorder` (`AVCaptureSession` → Float32).
2. Write: `AudioTranscriber.writeWAV` — 16 kHz mono + peak normalize.
3. Do not skip silence rejection (near-zero peak often means Bluetooth converter failure).

### Touch auto-insert behavior

Edit `TextInserter` only. Keep clipboard-as-fallback. Do not require network. Respect Accessibility denial (copy-only path).

### Add a notification

Only if you truly need fan-out. Prefer method calls. Accessibility trust is the only app-wide name today (`.accessibilityTrustChanged` next to `KeyboardShortcutManager`).

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
- Debug uses `Typeless.debug.entitlements` (sandbox **off**) so hotkeys/AX work from DerivedData.
- Release uses `Typeless.entitlements` (sandbox **on**).
- Do not commit DerivedData, `.build`, or user xcuserdata.

**Accessibility when debugging from Xcode:** enable the **DerivedData** binary (not only `/Applications/Typeless.app`) in System Settings → Privacy & Security → Accessibility. `AccessibilityAuth.processPathHint` shows the path.

---

## Security & Entitlements

**Release** (`Typeless.entitlements`):

- `com.apple.security.app-sandbox`
- `com.apple.security.device.audio-input`
- `com.apple.security.network.client` — model download only
- `com.apple.security.files.user-selected.read-only`

**Debug** (`Typeless.debug.entitlements`): sandbox disabled + `get-task-allow` for iterative hotkey/AX work.

Never expand network entitlements without a clear product need. Do not send audio or transcripts off-device.

---

## Agent Workflow

1. **Explore** with Grep/Read; match existing style before editing.
2. **Prefer surgical edits** over large rewrites of `SettingsView` / overlay code.
3. **Respect layers**: Views → ViewModels → Services → system frameworks.
4. **No new third-party deps** unless agreed; WhisperKit is the only SPM product.
5. **After behavior changes**, run `./test-build.sh` or Xcode build; run `TypelessTests` when touching models/errors/history.
6. **Cite code** as `startLine:endLine:path` when explaining.
7. Stay concise: concrete diffs and examples over long essays.
8. **YAGNI**: do not reintroduce AppState, design-token files, popover mini-app shell, empty SwiftUI `Settings` scenes, or notification buses for single-caller actions.
9. Treat **hold-to-dictate + auto-insert** as the product spine; polish that path first.

### Known debt / pitfalls

- `SettingsView.swift` is large (~450+ lines) with multi-page sidebar chrome.
- File headers may still say “VocalText”.
- `SettingsView` / `KeyboardShortcutManager` share `QuickRecordShortcutKey` + `QuickRecordShortcutEnabled` — keep them in sync.
- Sandbox vs Accessibility: Release sandbox + global hotkeys is constrained; Debug intentionally unsandboxed.
- Menu dictate is **toggle** (no hold-poll); Carbon is **hold**. Keep that distinction in `KeyboardShortcutManager` session APIs.

---

## References

- [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession)
- [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)
- [Accessibility / AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement)
- [Carbon Event Manager hot keys](https://developer.apple.com/documentation/carbonsound)
