# 系统适配（P0 起）

P0 已建立 WindowContext、ImeProfiles、ImeController，提供有限等待、保守焦点检查和状态失败返回；真实搜狗兼容性待反馈/UAT。TSF 当前 profile 仅作会话提示，不能证明目标窗口身份；会话级激活仅在诊断脚本显式执行，不接入默认程序。

P1 HotkeyBindings 提供绑定、失败回退、暂停与退出清理。P2 ClipboardService、TextSender 和 InputRuntime 已实现有界复制、序列号及来源检查、全部格式恢复和逐字符目标检查，均可注入适配器做故障测试；权限处理仍待完善。真实应用兼容结果放 `tests/compatibility-results.md`。

P3 WindowContext 增加 processKnown/titleKnown，区别读取失败与合法空标题；焦点可靠性仍独立以 focusKnown 表示。无效或已销毁窗口不伪造上下文；隐藏自有窗口的进程、标题、类名读取已有自动验证，未据此扩大浏览器输入框焦点能力。

本轮 SelectionProbe 补充原生选区端点、UIA TextPattern 和焦点元素检查，未知选区不复制，UIA 设置连接/事务超时。ImeController 根据目标中文布局及 IMM 模式操作，线程 profileHint 仅诊断；首字符稳定等待可被焦点/暂停取消。NativeHotkeys 使用键盘钩子及 Alt 菜单抑制，PollScheduler 供 P4 轮询。真实修正版待复测。
