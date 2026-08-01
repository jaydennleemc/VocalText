# Typeless

Hold-to-dictate for macOS. Speak anywhere; on-device Whisper inserts text into the focused field.

[English](README.md) · [简体中文](README_zh-CN.md) · [繁體中文](README_zh-TW.md)

## Features

- Global hold shortcut (default **⌘⇧D**) → speak → release → auto-insert
- On-device only (WhisperKit / Core ML); network only for model download
- Models: small / medium (default) / large-v3
- Local history, mic device picker, menu bar agent (no Dock icon)

## Install

1. Download from [Releases](https://github.com/jaydennleemc/Typelesss/releases)
2. Move to Applications and launch
3. Allow **Microphone** and **Accessibility** (hotkey + insert into other apps)

First launch may download the default **medium** model (~1.5 GB).

## Use

| | |
|---|---|
| Dictate | Hold **⌘⇧D**, speak, release |
| Settings | Menu bar → Settings… (**⌘,**) |
| History | Menu bar → History (**⌘Y**) |

## Build

```bash
git clone https://github.com/jaydennleemc/Typelesss.git
open Typeless.xcodeproj   # or ./test-build.sh
```

macOS 15.5+, full Xcode. Contributor map: [AGENTS.md](AGENTS.md).
