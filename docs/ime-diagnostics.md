# IME 诊断字段

`tests/ime-smoke.ahk` 是独立诊断工具，Ctrl+Alt+F8 读取，F9 设置中文，F10 设置英文。v2 提示额外包含 requested、十六进制 conversion 和 native，便于区分操作目标与实际读回状态。

| 字段 | 含义 |
| --- | --- |
| requested | 本次操作目标：Read、Chinese 或 English |
| mode | 工具根据系统字段判定的 Chinese、English、Unknown 或 Unsupported |
| profileHint | TSF 当前上下文的输入法身份提示；SogouPinyin 为搜狗。它不是目标窗口身份的可靠证明 |
| open | IME 开启状态：1 开启，0 关闭。在已识别的中文输入法中，关闭通常表示直接字母输入；不是卸载/禁用输入法 |
| conversion | 位标记的十进制值，各位表示不同模式；不是分数或中文概率 |
| native | conversion 的 `0x0001` 位，中文输入法的本地语言模式标志 |
| focusKnown | 1 表示取得了属于目标窗口的焦点控件；0 表示未知。1 也不保证区分浏览器同一控件内的不同网页输入框 |

- `1025 = 0x0401 = 0x0400 + 0x0001`：NATIVE 位开启，另有 SYMBOL 模式标志。
- `1024 = 0x0400`：NATIVE 位关闭，SYMBOL 位仍在。第三方 IME 的实际表现不能仅由这个位推断。
- `0`：这些 conversion 位均关闭；配合 open=0 是本次搜狗英文观测值。

当前保守判定：有效的 open=0 为 English；open=1 且 native=1 为 Chinese；open=1/native=0 为 Unknown。这种 Unknown 可以显式请求中文/英文，但不能当作已经在英文模式。

Observed 表示成功读取字段；AlreadyCorrect 表示已有目标状态，不再发请求；Verified 表示发请求后读回符合目标。三者仍需与真实输入效果核对，不能代替全部应用兼容验收。

2026-10-04 用户确认 smoke 中英文切换均符合预期。重喂反馈暴露了线程 profileHint 的硬门槛问题，现已移除：操作依据目标窗口中文语言布局及可读 IMM 模式，不拿脚本线程提示拒绝已切回的中文输入法，也不据此声称目标身份已可靠识别。重喂在最后复制后、删除后各检查连续 100ms 中文状态；失败为 ReadinessFailed，不发送首字符或保留删除后的缓存。自动规则没有持续纠正或循环重试。

参考：[Windows conversion 模式](https://learn.microsoft.com/en-us/windows/win32/intl/ime-conversion-mode-values)、[Windows SDK 位定义](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/imm.h)。
