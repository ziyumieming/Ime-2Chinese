# 进程与标题规则（历史实现，已冻结）

按 [Issue #4 决策](issue-4-decisions.md)，窗口自动切换停止后续开发，规则配置入口与示例已移除。不创建独立规则文件，不扩展匹配条件。P3/P4 代码、旧配置读取和显式历史入口保留供回归；普通入口和仅重喂入口不执行自动规则。以下仅记录旧接口，不作为当前配置指引。

规则放在 `%AppData%\ImeAssist\settings.ini` 中，每条一个 `[Rule.编号]` 节。编号只能含英文字母、数字、下划线或连字符，忽略大小写且不能重复。`Process` 是完整进程文件名，例如 `msedge.exe`，不能写路径、通配符或空白。`TitleContains` 可省略；非空时按窗口标题的文字包含匹配，忽略大小写，不解释正则表达式或通配符。`Mode` 支持 `Chinese`、`English`、`Ignore`。

**从文件上到下取第一条命中。** 不按编号排序，也不自动把标题规则提到前面。Ignore 是有身份的例外规则，命中后停止匹配并保持当前模式；无匹配也保持当前模式。把例外和具体标题规则放在该进程的通用规则之前。

下面配置依次表示：Edge 标题含 `Private` 时忽略；含 `中文资料` 时请求中文；其余 Edge 窗口请求英文；记事本请求中文。

```ini
[Rule.EdgePrivate]
Process=msedge.exe
TitleContains=Private
Mode=Ignore

[Rule.EdgeChinese]
Process=msedge.exe
TitleContains=中文资料
Mode=Chinese

[Rule.EdgeDefault]
Process=msedge.exe
Mode=English

[Rule.Notepad]
Process=notepad.exe
Mode=Chinese
```

| 固定窗口上下文 | 第一条命中 | 结果 |
| --- | --- | --- |
| msedge.exe，Private 中文资料 - Edge | EdgePrivate | Ignore |
| MSEDGE.EXE，中文资料 - Edge | EdgeChinese | Chinese |
| msedge.exe，Other - Edge | EdgeDefault | English |
| notepad.exe，任意标题或空标题 | Notepad | Chinese |
| firefox.exe，中文资料 | 无 | NoMatch |

规则示例文件已删除；上面的匹配样例仅用于解释历史引擎和已有测试。`Private` 只是匹配文字，不检测隐私模式。旧配置默认无规则；不会自动删除已有用户规则，也不会为用户创建新规则。

窗口标题读取失败时，不能当作空标题。如果当前进程更早的标题例外无法判断，本轮返回无匹配（TitleUnavailable），不越过例外执行后面的通用规则。真正的空标题是已知标题，仍可命中通用规则。进程读取失败则返回 ProcessUnavailable。焦点是否已知单独记录；匹配结果不等于目标可操作，后续切换模块还须检查有效焦点。

规则身份以节名编号为准。标题刷新、规则位置移动、修改无关规则、仅大小写变化都不改变同一有效命中；不同编号即使动作相同也算变化。同一编号的动作或匹配条件被修改，则视为有效规则改变，供 P4 在重载时重新评估。修改未命中规则不会要求重新应用当前命中，因此可以继续尊重手动选择。

开发接口：`RuleEngine(rules).Match(context)` 输出 `matched`、`ruleId`、规范化 `identity`、`mode`、位置和原因；`HasTitleRules(processName)` 用于判断标题变化是否需要重匹配；`RuleEngine.SameMatch(previous, current)` 比较身份及匹配定义，不比较实际窗口标题和数组位置。引擎复制规则和结果值，不操作窗口、IME、热键、计时器或日志。窗口标题和完整规则结果不写入日常诊断。

检查范围见 [测试方案](testing-strategy.md)；阶段进度见 [ROADMAP](../ROADMAP.md)。
