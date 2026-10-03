# Windows AHK 输入法辅助工具架构计划

## Summary

采用“模块化 AHK v2”结构：保持单进程、轻量后台常驻，不引入 .NET。两个主功能拆成独立 feature：`RefeedFeature` 负责“选中文本重新喂给中文输入法”，`AutoSwitchFeature` 负责“按窗口规则自动切换输入法状态”。底层共享窗口探测、IME 控制、剪贴板保护、配置、日志、托盘通知等模块。

项目目标是先把当前 `core.ahk` 和 `test.ahk` 的原型能力工程化，而不是过早做复杂 GUI 或跨平台抽象。

## Project Structure

建议结构：

```text
IME/
  main.ahk
  config/
    settings.example.ini
  src/
    App.ahk
    config/
      ConfigStore.ahk
      Defaults.ahk
    common/
      Logger.ahk
      Notify.ahk
      TextRules.ahk
    system/
      ClipboardService.ahk
      WindowContext.ahk
      ImeController.ahk
      TextSender.ahk
      PermissionChecker.ahk
    features/
      RefeedFeature.ahk
      AutoSwitchFeature.ahk
    rules/
      RuleEngine.ahk
      WindowRule.ahk
    ui/
      TrayMenu.ahk
      SettingsWindow.ahk
  tests/
    manual-checklist.md
    unit-text-rules.ahk
    unit-rule-engine.ahk
  docs/
    architecture.md
    user-guide.md
```

职责分布：

- `main.ahk`：唯一入口，加载模块、创建 `App`、启动热键和后台监听。
- `App.ahk`：应用生命周期协调，不直接处理剪贴板、IME、窗口细节。
- `RefeedFeature.ahk`：注册转换热键和撤回热键，编排“取选中文本 -> 校验 -> 切中文 -> 删除原文 -> 逐键发送”。
- `AutoSwitchFeature.ahk`：定时或窗口变化时获取活动窗口，调用规则引擎决定目标输入模式。
- `ImeController.ahk`：封装 `ImmGetDefaultIMEWnd`、`WM_IME_CONTROL`、中英状态判断、切换动作。
- `WindowContext.ahk`：统一返回当前窗口信息：进程名、标题、窗口句柄、焦点控件句柄、窗口类。
- `RuleEngine.ahk`：根据配置规则决定 `Chinese`、`English`、`Ignore` 或 `NoMatch`。
- `ConfigStore.ahk`：读取/保存 INI；首次启动从默认值生成用户配置。
- `TrayMenu.ahk`：托盘入口：启用/暂停、打开设置、查看最近日志、退出。
- `SettingsWindow.ahk`：第一版只做基础设置：热键、发送间隔、自动切换开关、规则编辑入口。

运行时配置放在用户目录，例如 `%AppData%\ImeAssist\settings.ini`；仓库只保留 `settings.example.ini`，避免把个人规则提交进去。

## Key Interfaces

核心模块之间使用简单对象/Map，不做重型类层级。

`WindowContext.GetActive()` 返回：

```ahk
{
  hwnd: 123456,
  controlHwnd: 234567,
  processName: "Code.exe",
  title: "notes.md - Visual Studio Code",
  className: "Chrome_WidgetWin_1"
}
```

`RuleEngine.Match(context)` 返回：

```ahk
{
  action: "Chinese" | "English" | "Ignore" | "NoMatch",
  ruleName: "WeChat default Chinese"
}
```

`ImeController` 暴露：

```ahk
GetStatus(targetHwnd)
EnsureChinese(targetHwnd)
EnsureEnglish(targetHwnd)
ToggleIfNeeded(targetHwnd, targetMode)
```

`RefeedFeature` 暴露：

```ahk
Start()
Stop()
ConvertSelection()
UndoLast()
```

配置第一版使用 INI，保守但足够：

```ini
[General]
EnableRefeed=1
EnableAutoSwitch=1
RefeedHotkey=!z
UndoHotkey=!+z
SendIntervalMs=10
MaxRefeedLength=50

[AutoSwitch]
PollIntervalMs=300
DefaultAction=Ignore

[Rule.Code]
Process=Code.exe
TitleContains=
Mode=English

[Rule.WeChat]
Process=WeChat.exe
TitleContains=
Mode=Chinese
```

## Implementation Plan

1. 基础骨架  
   创建 `main.ahk`、`src/App.ahk`、配置模块和托盘模块。先做到应用能启动、读取默认配置、托盘可退出。

2. 抽取文本重喂功能  
   把当前 `core.ahk` 拆入 `RefeedFeature`、`ClipboardService`、`TextSender`、`TextRules`。保持现有 `Alt+Z` 和 `Alt+Shift+Z` 行为不变。

3. 抽取 IME 控制  
   把当前 `test.ahk` 的 IME 探测逻辑迁入 `ImeController`。为转换前增加 `EnsureChinese()`，失败时不删除原选中文本，只提示和记录日志。

4. 加入窗口上下文与规则引擎  
   实现 `WindowContext` 和 `RuleEngine`，支持按进程名匹配，后续再加标题包含匹配。先不做复杂控件级规则。

5. 实现自动切换  
   `AutoSwitchFeature` 用 `SetTimer` 每 300ms 检查活动窗口变化；只有窗口变化时执行规则，避免持续打扰当前输入状态。

6. 设置与可观测性  
   加基础设置窗口、最近 5 条操作日志、失败原因提示。日志只保存在内存或简单文本文件，第一版不做复杂日志系统。

7. 打包与文档  
   用 Ahk2Exe 打包，写 `docs/user-guide.md`，说明热键、规则配置、管理员权限限制和常见失败场景。

## Test Plan

- 单元脚本测试：`TextRules` 验证英文串、空白、过长、中文混入、符号混入。
- 单元脚本测试：`RuleEngine` 验证进程匹配、标题匹配、无匹配、Ignore 优先级。
- 手动测试：记事本、VS Code、微信/聊天软件、浏览器输入框。
- 手动测试：中文输入法英文模式下触发重喂，应弹出候选或进入中文组合状态。
- 手动测试：非英文选中文本、超长文本、无选中文本，不应删除原内容。
- 手动测试：管理员窗口权限不足时，应提示失败，不应误删文本。
- 手动测试：剪贴板原内容包含富文本/图片时，转换后应尽量恢复。

## Assumptions

- 第一版只支持 Windows + AutoHotkey v2。
- 不引入 .NET、Electron、Python 后台服务或外部 GUI 框架。
- 自动切换第一版以“进程名 + 可选窗口标题”为主，不做浏览器域名、VS Code 文件类型、UIA 控件语义识别。
- 配置采用 INI；如果后续规则复杂化，再迁移到 JSON。
- IME 状态控制优先使用 IMM/窗口消息；遇到不支持的软件时记录失败并保守退出，不强行发送破坏性按键。
