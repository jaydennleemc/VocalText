# Quick Record Shortcut - Design Decisions

## Storage Format

### UserDefaults Keys
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `QuickRecordShortcutEnabled` | Bool | `true` | 是否启用快速录音快捷键 |
| `QuickRecordShortcutKey` | String | `"cmd+shift+v"` | 快捷键字符串格式 |

### Format Specification
- **格式**: `"cmd+shift+v"` (小写)
- **结构**: 修饰键+字母, 使用 `+` 分隔
- **修饰键顺序**: cmd → shift → option → control
- **示例**:
  - `cmd+shift+v` (默认)
  - `cmd+option+r`
  - `control+shift+t`

## Implementation Details

### AppDelegate 注册默认值
在 `TypelessApp.swift` 的 `applicationDidFinishLaunching` 中调用 `registerDefaults()`:
```swift
UserDefaults.standard.register(defaults: [
    "QuickRecordShortcutEnabled": true,
    "QuickRecordShortcutKey": "cmd+shift+v"
])
```

### KeyboardShortcutManager 解析逻辑
1. 读取 `QuickRecordShortcutEnabled` 检查是否启用
2. 读取 `QuickRecordShortcutKey` 获取快捷键字符串
3. 使用 `parseShortcut()` 解析字符串为键和修饰键
4. 验证事件 modifiers 和 character 是否匹配

### 向后兼容性
- 首次启动时设置默认值
- 如果 UserDefaults 中已有值, 则不覆盖
- 使用 `registerDefaults` 而非直接 `set` 确保不影响用户手动设置的值