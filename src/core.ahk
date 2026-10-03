#Requires AutoHotkey v2.0

global LastProcessed := "" ; 存储最近一次成功处理并发送的字符串

!z:: {
    global LastProcessed
    ; 备份当前剪贴板内容，以防污染
    ClipSaved := ClipboardAll() ; 当前剪贴板对象的所有格式的备份

    ; 获取选中的文本
    A_Clipboard := "" ; 搭配用于检测剪贴板内容更新
    Send "^c"
    if !ClipWait(0.3) {
        ; MsgBox "未能获取选中的文本，请重试。"
        A_Clipboard := ClipSaved ; 未能获取文本也要恢复剪贴板内容
        return
    }

    caughtText := A_Clipboard
    ; 长度过长时警告
    if StrLen(caughtText) > 50 {
        SoundBeep 200, 100
        A_Clipboard := ClipSaved
        return
    }

    ; 如果含有中文、标点符号或其他字符，则判定不符
    if !RegExMatch(caughtText, "^[a-zA-Z\s]+$") {
        SoundBeep 440, 150 ; 提示音：低频蜂鸣声 440Hz，持续 150ms
        A_Clipboard := ClipSaved
        return
    }

    LastProcessed := caughtText ; 在正式删除前，先记录缓存，以便撤回

    ; 去除空白符后进行二次判定
    selectedText := RegExReplace(caughtText, "\s", "")
    if (selectedText = "") {
        A_Clipboard := ClipSaved
        return
    }

    ; 删除原有选中内容
    Send "{BS}"

    ; 逐个字符模拟按键发送（Send\SendInput），而不是发送文本（SendText）
    loop parse, selectedText {
        Send A_LoopField
        Sleep 10 ; 给 IME 一点反应时间
    }

    ; 恢复剪贴板内容
    A_Clipboard := ClipSaved
    ClipSaved := "" ; 释放剪贴板备份对象

}

!+z:: {
    global LastProcessed
    if (LastProcessed = "")
        return
    ; SendText 原样输出不会触发输入法
    SendText LastProcessed
    SoundBeep 1880, 100
}
