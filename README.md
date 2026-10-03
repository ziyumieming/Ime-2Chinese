# Ime-2Chinese

Windows + AutoHotkey v2 输入法辅助工具，面向搜狗拼音，微软拼音用于兼容测试。

- **文本重喂**：将误输的英文字母重新送入已有中文输入法，由用户选择候选。
- **取回原文**：在当前光标处插入最近缓存的原文，作为兜底；撤销交给应用的 `Ctrl+Z`。
- **自动切换**：按进程和窗口标题规则切换中英文模式，尊重后续手动选择。

## 当前状态

项目正在从原型进入模块化开发。需求与目录骨架已建立，主入口仅用于检查加载，尚未注册重喂或自动切换功能。搜狗在浏览器中的检测、切换和激活能力仍待 P0 实测。

直接在仓库主分支 `main` 开发和提交，不采用功能分支或 PR 流程。新项目见 [main](https://github.com/ziyumieming/Ime-2Chinese/tree/main)。

## 运行与文档

安装 AutoHotkey v2 后，可以执行加载检查：

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /ErrorStdOut .\main.ahk --check
```

直接运行 `main.ahk` 目前显示开发阶段提示并退出，不启动后台功能。

- [ROADMAP.md](ROADMAP.md)：阶段进度、已完成事项、验证和下一步。
- [PLAN.md](PLAN.md)：完整需求、设计边界和验收标准。
- [用户指南](docs/user-guide.md)：原型使用与当前限制。
- [架构说明](docs/architecture.md)：目录职责和实现顺序。
- [手动验收](tests/manual-checklist.md)、[兼容记录](tests/compatibility-results.md)。

`src/core.ahk`、`src/test.ahk` 是用户编写的旧原型；可独立运行，但不要与后续主程序同时运行。原型默认 `Alt+Z` 重喂、`Alt+Shift+Z` 取回原文，仅接受不超过 50 字符的英文字母和空白，去掉空白后以 10ms 间隔逐键发送。原型不自动确认中文模式，不能当作已完成的新工具。

个人配置、日志、任务临时文件和旧 exe 不上传。每个后续功能点使用独立 commit，并同步更新 ROADMAP、对应验证记录和必要文档。
