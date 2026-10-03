# 系统适配（P0 起）

P0 已建立 WindowContext、ImeProfiles、ImeController，提供有限等待、保守焦点检查和状态失败返回；真实搜狗兼容性待反馈/UAT。TSF 当前 profile 仅作会话提示，不能证明目标窗口身份；会话级激活仅在诊断脚本显式执行，不接入默认程序。

P1 HotkeyBindings 提供绑定、失败回退、暂停与退出清理，可注入驱动做故障测试。P2 后续创建 ClipboardService、TextSender 和权限处理。真实应用兼容结果放 `tests/compatibility-results.md`。
