#Requires AutoHotkey v2.0

; 按下 F1 触发检测
F1:: {
    ; 获取当前活跃（最顶层）窗口的句柄
    hWnd := WinGetID("A")
    if !hWnd {
        ToolTip("未找到活动窗口")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 尝试获取当前窗口内具有焦点的控件句柄（如记事本里具体的文本框 Edit1）
    TargetWnd := hWnd
    try {
        ctlName := ControlGetFocus("A")
        if ctlName {
            TargetWnd := ControlGetHwnd(ctlName, "A")
        }
    }

    ; 调用 imm32.dll 获取默认的 IME 窗口句柄
    DefaultIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", TargetWnd, "Ptr")

    ; 如果获取不到，退回使用主窗口句柄重试 (部分软件主窗口才掌管 IME)
    if (DefaultIMEWnd == 0) {
        DefaultIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
    }

    ; 如果仍然获取不到，给出提示结束
    if (DefaultIMEWnd == 0) {
        ToolTip("无法获取该窗口的 IME 句柄：可能是 UWP/新架构软件`n窗口句柄: " hWnd)
        SetTimer(() => ToolTip(), -3000)
        return
    }

    ; 使用 DllCall 发送窗口消息，直接与操作系统底层通信，避免 AHK 本身的 SendMessage 会出现的 Target window not found 异常。
    ; WM_IME_CONTROL = 0x0283, IMC_GETOPENSTATUS = 0x0005,  IMC_GETCONVERSIONMODE = 0x0001
    isOpen := DllCall("SendMessage", "Ptr", DefaultIMEWnd, "UInt", 0x0283, "UPtr", 0x0005, "Ptr", 0, "Ptr")
    convMode := DllCall("SendMessage", "Ptr", DefaultIMEWnd, "UInt", 0x0283, "UPtr", 0x0001, "Ptr", 0, "Ptr")

    ; 格式化信息并显示气泡提示 (ToolTip)
    info := "==== 输入法状态测试 ===="
        . "`n主窗口句柄: " hWnd
        . "`n焦点控件句柄: " TargetWnd
        . "`nIME句柄: " DefaultIMEWnd
        . "`n-----------------------"
        . "`n开关状态(OpenStatus): " isOpen "  (0=原生英文, 1=处于输入法接管/中文)"
        . "`n转换模式(ConvMode): " convMode " "

    ToolTip(info)

    ; 3秒钟后自动隐藏提示框
    SetTimer(() => ToolTip(), -3000)
}
