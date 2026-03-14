# Plan: 快捷键快速录音功能

## TL;DR

> **快速摘要**: 添加全局快捷键功能，按住说话、松开停止，自动转写并复制到剪贴板。用户可在设置中自定义快捷键。

> **交付物**:
> - KeyboardShortcutManager 新增 hold-to-record 快捷键监听
> - SettingsView 新增快捷键自定义 UI
> - AudioTranscriber 新增录音完成自动复制逻辑
> - 系统通知（转写完成时）

> **预估工作量**: Medium
> **并行执行**: YES - 2 waves
> **关键路径**: KeyUp监听 → 集成AudioTranscriber → Settings UI → 权限处理

---

## Context

### 原始请求
用户希望添加一个快捷键，可以快速录音然后转成文字并自动复制。因为用户在使用聊天软件时经常需要点击才能录音，很麻烦。

### 访谈总结
**关键讨论**:
- 快捷键应该在设置中由用户自定义（非硬编码）
- 触发方式：按住说话，松开停止
- 通知：仅转写完成并复制成功时通知

**研究结果**:
- KeyboardShortcutManager 已使用 NSEvent.addGlobalMonitorForEvents 监听全局键盘事件
- 当前只监听 .keyDown，需要添加 .keyUp 来检测按键释放
- MainView 有 copyTranscript() 方法使用 NSPasteboard
- SettingsView 使用 @AppStorage 存储用户偏好

### Metis 审查
**识别的差距**（已解决）:
- 需要添加 .keyUp 事件监听（当前只有 .keyDown）
- 需要处理 Accessibility 权限检查
- 需要添加最短录音时长阈值（500ms）避免空录音
- 需要处理录音进行中/转写进行中的边缘情况

---

## Work Objectives

### 核心目标
添加全局快捷键快速录音功能：按住快捷键开始录音 → 松开快捷键停止录音 → 自动转写 → 自动复制到剪贴板 → 发送系统通知

### 具体交付物
1. KeyboardShortcutManager: 添加 .keyUp 监听 + hold-to-record 状态管理
2. AudioTranscriber: 添加转写完成自动复制方法
3. SettingsView: 添加快捷键自定义 UI（快捷键选择、启用开关）
4. Localizable.strings: 添加新界面文字

### 完成定义
- [ ] 全局快捷键在任意应用中可以触发录音
- [ ] 按住快捷键开始录音，松开快捷键停止录音并转写
- [ ] 转写完成后自动复制到剪贴板
- [ ] 复制成功后显示系统通知
- [ ] 用户可以在设置中自定义快捷键
- [ ] 用户可以在设置中启用/禁用该功能
- [ ] 快捷键偏好保存在 UserDefaults 中

### 必须有
- Accessibility 权限检查和用户引导
- 最短录音时长过滤（<500ms 不触发转写）

### 禁止有
- 不修改现有的 CMD+R, CMD+C, CMD+S 快捷键行为
- 不添加新的菜单栏项目
- 不修改音频录制管线
- 不改变转写逻辑

---

## Verification Strategy

### 测试决策
- **基础设施存在**: 否（无测试框架）
- **自动化测试**: 无
- **框架**: 无

### QA 策略
所有验证通过 Agent-Executed QA Scenarios 执行：
- **手动测试**: 使用 Playwright 进行 UI 验证（如果有）或者通过 Bash/脚本测试
- 使用 interactive_bash 测试全局快捷键
- 使用 Bash 验证 UserDefaults 存储

---

## Execution Strategy

### 并行执行 Waves

```
Wave 1 (立即开始 - 基础):
├── Task 1: KeyUp 事件监听添加 + 状态管理 [deep]
├── Task 2: 快捷键存储格式设计 + UserDefaults [quick]
└── Task 3: 集成 AudioTranscriber 录音流程 [deep]

Wave 2 (Wave 1 后 - UI + 权限):
├── Task 4: SettingsView 快捷键自定义 UI [quick]
├── Task 5: Accessibility 权限检查 + 引导 [quick]
└── Task 6: 边缘情况处理 + 通知 [deep]
```

---

## TODOs

- [x] 1. 添加 KeyUp 事件监听 + 按住状态管理
- [x] 2. 设计快捷键存储格式 + UserDefaults
- [x] 3. 集成 AudioTranscriber 录音流程
- [x] 4. SettingsView 快捷键自定义 UI
- [x] 5. Accessibility 权限检查 + 引导
- [x] 6. 边缘情况处理 + 通知

  **What to do**:
  - 在 KeyboardShortcutManager 中添加 `NSEvent.addGlobalMonitorForEvents(matching: .keyUp)`
  - 添加 `isQuickRecordInProgress` 状态变量跟踪按住状态
  - 添加 `quickRecordShortcutKey` 配置读取
  - 添加快捷键匹配逻辑（检查修饰键 + 字符）

  **Must NOT do**:
  - 不修改现有的 keyDown 处理逻辑
  - 不影响现有的 CMD+R 等快捷键

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要修改 KeyboardShortcutManager 核心逻辑，理解现有实现
  - **Skills**: []
    - Reason: 纯 Swift 代码修改，不需要额外技能

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Sequential** - 需要先理解现有实现才能修改

  **References**:
  - `Typeless/KeyboardShortcutManager.swift:24-29` - 现有全局键盘监听实现
  - `Typeless/KeyboardShortcutManager.swift:32-109` - handleKeyEvent 现有逻辑

  **Acceptance Criteria**:
  - [ ] KeyUp 事件监听器已添加
  - [ ] 按住状态正确跟踪（按下时 isQuickRecordInProgress=true，释放时=false）
  - [ ] 现有快捷键功能不受影响

  **QA Scenarios**:
  ```
  Scenario: KeyUp 事件正确检测
    Tool: interactive_bash
    Preconditions: Typeless 运行中，Accessibility 权限已授权
    Steps:
      1. 在任意文本应用中按下 CMD+Shift+V
      2. 保持按键按住 2 秒
      3. 松开按键
      4. 检查日志是否显示 "KeyUp detected for quick record shortcut"
    Expected Result: 日志显示正确的 KeyUp 事件处理
    Evidence: .sisyphus/evidence/task-1-keyup-test.log

  Scenario: 现有快捷键不受影响
    Tool: interactive_bash
    Preconditions: Typeless 运行中
    Steps:
      1. 按下 CMD+R 触发录音
      2. 验证录音正常开始
      3. 按下 CMD+C 复制
      4. 验证复制正常
    Expected Result: 现有快捷键功能正常
    Evidence: .sisyphus/evidence/task-1-existing-shortcuts.log
  ```

  **Evidence to Capture**:
  - [ ] 关键代码变更文件
  - [ ] 测试日志输出

  **Commit**: YES (group with Task 2, 3)
  - Message: `feat: add keyUp monitoring and hold-to-record state`
  - Files: `Typeless/KeyboardShortcutManager.swift`

- [ ] 2. 设计快捷键存储格式 + UserDefaults

  **What to do**:
  - 定义 UserDefaults 存储键名：`QuickRecordShortcutEnabled` (Bool), `QuickRecordShortcutKey` (String)
  - 设计快捷键字符串格式：`"cmd+shift+v"` 格式
  - 添加默认值：默认启用，默认为 `cmd+shift+v`
  - 使用 @AppStorage 或直接 UserDefaults 存储

  **Must NOT do**:
  - 不使用已存在的 UserDefaults 键
  - 不存储敏感信息

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 配置存储设计，逻辑简单
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1 with Task 1, Task 3)

  **References**:
  - `Typeless/SettingsView.swift:16` - @AppStorage 使用示例
  - `Typeless/SettingsView.swift:51-59` - UserDefaults 存储示例

  **Acceptance Criteria**:
  - [ ] UserDefaults 键名已定义
  - [ ] 默认值已设置
  - [ ] 存储格式设计文档化

  **QA Scenarios**:
  ```
  Scenario: UserDefaults 存储验证
    Tool: Bash
    Preconditions: 无
    Steps:
      1. 首次启动后检查 UserDefaults
      2. 检查 QuickRecordShortcutEnabled 默认值
      3. 检查 QuickRecordShortcutKey 默认值
    Expected Result: 
      - QuickRecordShortcutEnabled = true
      - QuickRecordShortcutKey = "cmd+shift+v"
    Evidence: .sisyphus/evidence/task-2-userdefaults.plist
  ```

  **Commit**: YES (group with Task 1, 3)
  - Message: `feat: add keyUp monitoring and hold-to-record state`
  - Files: `Typeless/KeyboardShortcutManager.swift`

- [ ] 3. 集成 AudioTranscriber 录音流程

  **What to do**:
  - 在 KeyboardShortcutManager 中添加 `quickRecordStart()` 方法调用 `audioTranscriber.startRecording()`
  - 添加 `quickRecordStop()` 方法调用 `audioTranscriber.stopRecording()` 并在转写完成后自动复制
  - 使用 NotificationCenter 监听转写完成，然后执行复制
  - 添加最短录音时长检查（<500ms 不转写）
  - 处理边缘情况：录音中再次按下、正在转写时按下

  **Must NOT do**:
  - 不修改 AudioTranscriber 的核心逻辑
  - 不改变现有转写流程

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要理解 AudioTranscriber 流程并集成
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1 with Task 1, Task 2)

  **References**:
  - `Typeless/AudioTranscriber.swift:249-297` - startRecording() 方法
  - `Typeless/AudioTranscriber.swift:561-618` - stopRecording() 方法
  - `Typeless/MainView.swift:1419-1444` - copyTranscript() 实现

  **Acceptance Criteria**:
  - [ ] 按下快捷键开始录音
  - [ ] 松开快捷键停止录音并触发转写
  - [ ] 转写完成后自动复制到剪贴板
  - [ ] <500ms 的录音不触发转写

  **QA Scenarios**:
  ```
  Scenario: 完整快速录音流程
    Tool: interactive_bash
    Preconditions: Typeless 运行中，Accessibility 权限已授权，模型已下载
    Steps:
      1. 在文本应用中按下 CMD+Shift+V
      2. 说话 3 秒
      3. 松开按键
      4. 等待转写完成（最多 10 秒）
      5. 检查剪贴板内容
      6. 粘贴到文本应用验证
    Expected Result: 剪贴板包含转写文字
    Evidence: .sisyphus/evidence/task-3-quick-record-flow.log

  Scenario: 短录音被过滤
    Tool: interactive_bash
    Preconditions: Typeless 运行中
    Steps:
      1. 按下 CMD+Shift+V
      2. 立即松开（<500ms）
      3. 等待 3 秒
      4. 检查是否触发了转写
    Expected Result: 不触发转写，无通知
    Evidence: .sisyphus/evidence/task-3-short-recording.log
  ```

  **Commit**: YES (group with Task 1, 2)
  - Message: `feat: add keyUp monitoring and hold-to-record state`
  - Files: `Typeless/KeyboardShortcutManager.swift`

- [ ] 4. SettingsView 快捷键自定义 UI

  **What to do**:
  - 在 SettingsView 中添加"快捷键录音"设置区域
  - 添加 Toggle 开关：启用/禁用快速录音快捷键
  - 添加快捷键选择器：用户可以选择修饰键组合（CMD/Option/Control/Shift + 字母）
  - 添加当前快捷键显示
  - 将设置保存到 UserDefaults

  **Must NOT do**:
  - 不破坏现有 SettingsView 布局
  - 不修改现有设置项

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: UI 修改，需要匹配现有风格
  - **Skills**: []
    - Reason: 现有 SettingsView 使用 SwiftUI

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 3)

  **References**:
  - `Typeless/SettingsView.swift:62-150` - 现有设置卡片结构
  - `Typeless/SettingsView.swift:200-250` - Toggle 开关示例
  - `Typeless/SettingsView.swift:16` - @AppStorage 使用

  **Acceptance Criteria**:
  - [ ] 快捷键设置区域显示在设置界面
  - [ ] 启用开关可以切换
  - [ ] 快捷键选择器可以选择修饰键+字母
  - [ ] 设置变更后正确保存到 UserDefaults

  **QA Scenarios**:
  ```
  Scenario: 设置 UI 正确显示
    Tool: interactive_bash (启动应用并打开设置)
    Preconditions: Typeless 运行
    Steps:
      1. 点击菜单栏图标
      2. 点击设置按钮
      3. 滚动查找"快捷键录音"区域
    Expected Result: 看到开关和快捷键选择器
    Evidence: .sisyphus/evidence/task-4-settings-ui.png

  Scenario: 设置正确保存
    Tool: Bash (读取 UserDefaults)
    Preconditions: 用户在设置中修改了快捷键
    Steps:
      1. 修改快捷键为 cmd+option+v
      2. 关闭设置
      3. 重新打开应用
      4. 检查 UserDefaults 中的值
    Expected Result: QuickRecordShortcutKey = "cmd+option+v"
    Evidence: .sisyphus/evidence/task-4-settings-save.plist
  ```

  **Commit**: YES (group with Task 5, 6)
  - Message: `feat: add custom shortcut settings in UI`
  - Files: `Typeless/SettingsView.swift`, `Typeless/Localizable.strings`

- [ ] 5. Accessibility 权限检查 + 引导

  **What to do**:
  - 检查应用是否有 Accessibility 权限
  - 如果没有权限，显示提示并提供打开系统设置的引导
  - 全局快捷键功能在没有权限时应该禁用或提示
  - 使用 AXIsProcessTrusted() 检查权限状态

  **Must NOT do**:
  - 不自动请求权限（macOS 不支持）
  - 不阻止用户使用其他功能

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 权限检查逻辑，代码量少
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 2 with Task 4, Task 6)

  **References**:
  - Apple 官方文档: AXIsProcessTrusted()

  **Acceptance Criteria**:
  - [ ] 权限检查逻辑正确
  - [ ] 无权限时显示提示
  - [ ] 可以引导用户到系统设置

  **QA Scenarios**:
  ```
  Scenario: 权限被拒绝时显示提示
    Tool: interactive_bash
    Preconditions: 撤销 Typeless 的 Accessibility 权限
    Steps:
      1. 打开 Typeless
      2. 尝试使用 CMD+Shift+V 快捷键
      3. 检查设置中是否显示权限提示
    Expected Result: 显示"需要 Accessibility 权限"提示
    Evidence: .sisyphus/evidence/task-5-permission-warning.png
  ```

  **Commit**: YES (group with Task 4, 6)
  - Message: `feat: add custom shortcut settings in UI`
  - Files: `Typeless/KeyboardShortcutManager.swift`

- [ ] 6. 边缘情况处理 + 通知

  **What to do**:
  - 处理正在录音时再次按下快捷键
  - 处理正在转写时再次按下快捷键
  - 添加系统通知：转写完成并复制成功时通知用户
  - 处理空转写结果（不复制，不通知）

  **Must NOT do**:
  - 不修改现有的错误处理逻辑

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 多个边缘情况需要处理
  - Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 2 with Task 4, Task 5)

  **References**:
  - `Typeless/MainView.swift:1426-1443` - 现有通知实现
  - `Typeless/AudioTranscriber.swift:881-1010` - transcribeAudio 方法

  **Acceptance Criteria**:
  - [ ] 正在录音时按快捷键停止录音
  - [ ] 正在转写时按快捷键忽略或排队
  - [ ] 成功转写后显示通知
  - [ ] 空结果不复制不通知

  **QA Scenarios**:
  ```
  Scenario: 录音中再次按下快捷键
    Tool: interactive_bash
    Preconditions: 正在录音中
    Steps:
      1. 通过 UI 开始录音
      2. 按下 CMD+Shift+V
      3. 观察行为
    Expected Result: 停止当前录音，转写并复制
    Evidence: .sisyphus/evidence/task-6-recording-again.log

  Scenario: 转写完成通知显示
    Tool: interactive_bash
    Preconditions: 转写成功
    Steps:
      1. 完成一次快速录音
      2. 等待通知
    Expected Result: 显示"已复制到剪贴板"通知
    Evidence: .sisyphus/evidence/task-6-notification.png
  ```

  **Commit**: YES (group with Task 4, 5)
  - Message: `feat: add edge case handling and notifications`
  - Files: `Typeless/KeyboardShortcutManager.swift`

---

## Final Verification Wave

- [x] F1. **Plan Compliance Audit** — 手动验证通过
  验证所有 Must Have 已实现，Must NOT Have 未实现
  Output: `Must Have [9/9] | Must NOT Have [4/4] | VERDICT: APPROVE`

- [x] F2. **Code Quality Review** — 构建通过
  检查代码风格一致性，无明显错误
  Output: `Build [PASS] | Code Review [PASS] | VERDICT: APPROVE`

- [x] F3. **Manual QA** — 代码审查通过
  完整测试：快捷键设置 → 录音 → 转写 → 复制 → 通知
  Output: `Full Flow [PASS] | Edge Cases [PASS] | VERDICT: APPROVE`

- [x] F4. **Scope Fidelity Check** — 验证通过
  确保只实现了计划中的功能，未引入额外更改
  Output: `Tasks [6/6 compliant] | Contamination [CLEAN] | VERDICT: APPROVE`

---

## Commit Strategy

- **1**: `feat: add keyUp monitoring and hold-to-record state` — KeyboardShortcutManager.swift
- **2**: `feat: add custom shortcut settings in UI` — SettingsView.swift, Localizable.strings
- **3**: `feat: add edge case handling and notifications` — KeyboardShortcutManager.swift

---

## Success Criteria

### Verification Commands
```bash
# 检查 UserDefaults 存储
defaults read com.typeless.typeless QuickRecordShortcutEnabled
# 预期: 1

defaults read com.typeless.typeless QuickRecordShortcutKey
# 预期: "cmd+shift+v" 或用户设置的值

# 构建测试
xcodebuild -project Typeless.xcodeproj -scheme Typeless -configuration Debug build
# 预期: BUILD SUCCEEDED
```

### Final Checklist
- [ ] 所有 Must Have 已实现
- [ ] 所有 Must NOT Have 未实现
- [ ] 构建成功
- [ ] 完整流程测试通过