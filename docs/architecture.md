# 架构说明

采用 Windows 原生 AutoHotkey v2，单进程、模块化、轻量常驻。P1 已实现常驻、配置和托盘；P0 系统模块提供独立诊断。P2 编排在普通入口和便携 EXE 接入，P3 规则随配置同步编译，P4 在全功能 MVP 接入轮询。

| 目录 | 职责 | 计划阶段 |
| --- | --- | --- |
| `main.ahk`、`src/App.ahk` | 入口、生命周期、功能协调 | P1 已实现；功能协调后续扩展 |
| `config`、`src/config` | 示例配置、默认值、读取与保存 | P1 |
| `src/common` | 日志、通知、文本规则 | P1/P2 |
| `src/system` | 窗口、IME、剪贴板、发送与权限 | P0/P2/P3 |
| `src/features` | 重喂/取回、自动切换编排 | P2/P4 |
| `src/rules` | 有序纯规则匹配 | P3 |
| `src/ui` | 托盘与基础设置 | P1/P5 |
| `tests` | 纯逻辑测试、手动验收、真实兼容结果 | 随功能维护 |
| `docs` | 架构和使用说明 | 随功能维护 |

2026-10-06 已恢复 P6，生成便携测试包；窗口自动切换继续冻结。可编辑检查、操作诊断/回调更新/导出、按键录制及登录自启已实现；真实桌面验证留给 UAT。

ConfigStore 严格解析 INI，用独立数组保留配置节出现顺序；原子替换配置，非法文件不重置。App 编译候选规则、更新热键/历史计时器和必要的 Startup 快捷方式，再保存并替换有效配置；失败回退绑定、计时器和自启快照。HotkeyRecorder 只在显式录制时启用，不收集文本；业务键临时注销，取消/松键后恢复。Logger 按操作保存有界步骤及已取得的文本/标题，向可见 DiagnosticsWindow 回调并合并窗口消息，无刷新计时器；主动导出当前快照。详见 [Issue #4 决策](issue-4-decisions.md)。普通 App 不挂输入处理器；AttachRefeed 接入手动功能，AttachAuto 仅保留为历史入口。

WindowContext 分别标记进程、标题和焦点是否可读，空标题不等于读取失败。RuleEngine 纯匹配进程及标题，返回第一条命中的稳定编号和动作；无法判断更早标题例外时不执行后续通用规则。SameMatch 忽略位置和实际标题变化，比较编号及规则定义；为 P4 保留手动选择和处理有效规则变化提供依据。见 [规则接口及示例](rules.md)。

RefeedFeature 只负责流程和单条内存缓存，注入 contexts、keys、clipboard、ime、sender。TextRules 保留 demo 边界；ClipboardService 用完整备份、序列号和来源进程检查保护清理；TextSender 在删除和每个字母前调用目标检查。IME 确认之后再次复制并比较选区，减少切换导致选区消失时误删的可能。每个热键等待、复制和消息请求均有界，发送中失败保留缓存。退出取消后续动作、清理剪贴板并清空缓存。

输入法种类与内部模式分开处理：按 Issue #1 新决定，重喂和自动操作均只调整当前可观察中文输入法内部模式，其他语言跳过，不激活另一输入法。选词归输入法与用户，撤销归应用，取回原文只提供单条内存缓存兜底。

更多接口、行为及验收见 [PLAN](../PLAN.md)，当前状态见 [ROADMAP](../ROADMAP.md)。

SelectionProbe 在复制前观察原生选区端点或 UIA TextPattern，未知时不复制；UIA 焦点元素补充同窗输入框检查。最后复制后及删除后连续 100ms 中文读回才允许发送；焦点/暂停条件可以取消模式确认和稳定等待。Chrome 提供者行为仍待 UAT。

EditableProbe 在选区/模式/复制前检查 Native Edit 样式或 UIA 只读/可用/密码元数据与角色，并保留 UIA 元素引用供发送复核。未能证明目标可编辑时跳过，不从“有选区”推断可写，也不改变焦点。终端需要独立适配，当前明确排除已知控制台/Terminal 窗口。

AutoSwitchFeature 仅在窗口进入、有效命中变化或明确恢复时请求一次；失败也记为已尝试，同规则标题刷新不纠正手动模式。InputCoordinator 让手动/自动动作互斥，手动结束在释放锁前记录当前匹配，重喂有破坏性尝试时保护原目标本次停留。PollScheduler 管理暂停、重载和退出。见 [全功能边界](auto-switch-mvp.md)。

P5 SettingsModel 规范化可读热键和编辑字段，再按基线比较合并最新文件；SettingsWindow 保留草稿，失败不关闭窗口。App.SaveSettings 使用共享锁和同一 ApplyCandidate 路径，保持暂停及失败回退。DiagnosticsWindow 仅显示应用状态和 Logger 内存记录；关闭隐藏、退出销毁，不增加轮询计时器。Logger 连续重复合并，Notify 有界跨消息去重。见 [设置与诊断](settings-and-diagnostics.md)。
