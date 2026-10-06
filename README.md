# Ime-2Chinese

Windows + AutoHotkey v2 输入法辅助工具，面向搜狗拼音，微软拼音用于兼容测试。

- **文本重喂**：将误输的英文字母重新送入已有中文输入法，由用户选择候选。
- **取回原文**：在当前光标处插入最近缓存的原文，作为兜底；撤销交给应用的 `Ctrl+Z`。
- **自动切换（已冻结）**：保留历史实现和测试，停止后续开发，规则配置入口已移除。

## 当前状态

当前便携测试版 **0.1.0-beta.2** 已完成打包及独立 EXE 启动验证。普通启动直接提供重喂、取回原文、设置、诊断与可选登录自启；按键后检查，不新增轮询；启动及每次操作均不弹出右下角通知，结果在“最近诊断”查看。窗口自动切换继续冻结。浏览器/记事本完整体验待 UAT，见 [Issue #4 决策及验收](docs/issue-4-decisions.md)。

便携包解压后双击 `Ime-2Chinese.exe`，无需安装 AHK。默认 **Alt+Z** 重喂、**Alt+Shift+Z** 取回，候选由用户选择。见 [便携版使用说明](docs/portable-guide.md)、[构建与 GitHub 自动发布](docs/packaging.md)。

直接在仓库主分支 `main` 开发和提交，不采用功能分支或 PR 流程。新项目见 [main](https://github.com/ziyumieming/Ime-2Chinese/tree/main)。

## 运行与文档

安装 AutoHotkey v2 后，可以执行加载检查：

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /ErrorStdOut .\main.ahk --check
```

双击 `main.ahk` 启动全部当前手动功能；双击托盘图标或选择“设置”修改偏好，点击“录制”直接按快捷键，可勾选当前用户登录后自动启动。设置是唯一配置修改入口。选择“最近诊断”查看实时操作过程或导出文本快照。配置位于 `%AppData%\ImeAssist\settings.ini`。窗口自动切换默认不运行；`--settings-only` 可用于仅设置/托盘的排查。托盘选择“退出”可结束程序。

开发检查：用 Python 运行 `tests/run-tests.py`；Python 仅供测试，运行主程序只需 AutoHotkey v2。真实输入法测试见 [测试方案](docs/testing-strategy.md)，可提前使用 `tests/ime-smoke.ahk`。

旧重喂 MVP `tests/refeed-mvp.ahk` / `--test-refeed` 保留兼容。`tests/features-mvp.ahk` / `--test-all` 仅保留为含自动切换的历史回归入口，不作为当前试用方向。在无候选的人工文本上试用；空选区时静默且不复制，其他语言输入法下静默跳过。步骤见 [重喂说明](docs/refeed-mvp.md)、[自动切换说明](docs/auto-switch-mvp.md)，字段见 [诊断说明](docs/ime-diagnostics.md)。

- [ROADMAP.md](ROADMAP.md)：阶段进度、已完成事项、验证和下一步。
- [PLAN.md](PLAN.md)：完整需求、设计边界和验收标准。
- [用户指南](docs/user-guide.md)：原型使用与当前限制。
- [设置与诊断](docs/settings-and-diagnostics.md)：修改偏好、保留文件改动、结果查看。
- [Issue #4 决策及待办](docs/issue-4-decisions.md)：范围调整、重喂/取回检查与诊断验收。
- [架构说明](docs/architecture.md)：目录职责和实现顺序。
- [手动验收](tests/manual-checklist.md)、[兼容记录](tests/compatibility-results.md)。

`src/core.ahk`、`src/test.ahk` 是用户编写的旧原型；可独立运行，但不要与后续主程序同时运行。原型默认 `Alt+Z` 重喂、`Alt+Shift+Z` 取回原文，仅接受不超过 50 字符的英文字母和空白，去掉空白后以 10ms 间隔逐键发送。原型不自动确认中文模式，不能当作已完成的新工具。

个人配置、日志、任务临时文件和旧 exe 不上传。每个后续功能点使用独立 commit，并同步更新 ROADMAP、对应验证记录和必要文档。

异步需求讨论使用仓库 [Issues](https://github.com/ziyumieming/Ime-2Chinese/issues)，每阶段开始查看新回复，在对应 Issue 评论处理结果；本地 REVIEW_QUEUE 不再维护。
