# Ime-2Chinese

Windows + AutoHotkey v2 输入法辅助工具，面向搜狗拼音，微软拼音用于兼容测试。

- **文本重喂**：将误输的英文字母重新送入已有中文输入法，由用户选择候选。
- **取回原文**：在当前光标处插入最近缓存的原文，作为兜底；撤销交给应用的 `Ctrl+Z`。
- **自动切换**：按进程和窗口标题规则切换中英文模式，尊重后续手动选择。

## 当前状态

P1 配置与常驻骨架已实现，P2 重喂/取回 MVP 已接入显式测试入口，P3 窗口上下文与规则引擎已完成自动验证。普通启动不占用输入功能热键、不自动切换；测试启动保留 demo 热键和参数。用户 smoke 反馈发现英文切换问题，现已修正设置请求及误判逻辑，真实桌面修正版待复测，完整兼容性仍待 UAT。

直接在仓库主分支 `main` 开发和提交，不采用功能分支或 PR 流程。新项目见 [main](https://github.com/ziyumieming/Ime-2Chinese/tree/main)。

## 运行与文档

安装 AutoHotkey v2 后，可以执行加载检查：

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /ErrorStdOut .\main.ahk --check
```

双击 `main.ahk` 启动托盘程序；配置位于 `%AppData%\ImeAssist\settings.ini`。当前常驻版本不注入文本、不自动切换输入法。托盘选择“退出”可结束程序。

开发检查：用 Python 运行 `tests/run-tests.py`；Python 仅供测试，运行主程序只需 AutoHotkey v2。真实输入法测试见 [测试方案](docs/testing-strategy.md)，可提前使用 `tests/ime-smoke.ahk`。

重喂 MVP：双击 `tests/refeed-mvp.ahk`，或运行 `main.ahk --test-refeed`。先手动启用搜狗，在没有候选的人工文本上测试；指定输入法激活与已有候选的保护尚未完成。步骤及限制见 [MVP 说明](docs/refeed-mvp.md)，数值含义见 [诊断字段](docs/ime-diagnostics.md)。

- [ROADMAP.md](ROADMAP.md)：阶段进度、已完成事项、验证和下一步。
- [PLAN.md](PLAN.md)：完整需求、设计边界和验收标准。
- [用户指南](docs/user-guide.md)：原型使用与当前限制。
- [规则说明与示例](docs/rules.md)：文件顺序、Ignore 例外及稳定规则身份；自动监听在 P4 接入。
- [架构说明](docs/architecture.md)：目录职责和实现顺序。
- [手动验收](tests/manual-checklist.md)、[兼容记录](tests/compatibility-results.md)。

`src/core.ahk`、`src/test.ahk` 是用户编写的旧原型；可独立运行，但不要与后续主程序同时运行。原型默认 `Alt+Z` 重喂、`Alt+Shift+Z` 取回原文，仅接受不超过 50 字符的英文字母和空白，去掉空白后以 10ms 间隔逐键发送。原型不自动确认中文模式，不能当作已完成的新工具。

个人配置、日志、任务临时文件和旧 exe 不上传。每个后续功能点使用独立 commit，并同步更新 ROADMAP、对应验证记录和必要文档。
