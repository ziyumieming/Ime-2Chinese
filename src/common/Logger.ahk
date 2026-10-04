#Requires AutoHotkey v2.0

; Accept only code identifiers, never input content, paths or window titles.
class Logger {
    __New(limit := 30, clock := unset) {
        if limit < 1
            throw ValueError("Diagnostic capacity must be positive")
        this.limit := limit, this.entries := []
        this.clock := IsSet(clock) ? clock : () => FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }
    Record(event, result) {
        if !RegExMatch(event, "^[A-Za-z0-9_]+$") || !RegExMatch(result, "^[A-Za-z0-9_]+$")
            throw ValueError("Diagnostic identifiers only")
        timestamp := this.clock.Call()
        if this.entries.Length {
            previous := this.entries[this.entries.Length]
            if previous.event = event && previous.result = result {
                previous.count += 1, previous.at := timestamp
                return
            }
        }
        this.entries.Push({at: timestamp, event: event, result: result, count: 1})
        while this.entries.Length > this.limit
            this.entries.RemoveAt(1)
    }
    Recent() {
        text := ""
        for entry in this.entries
            text .= entry.at "  " Logger.EventLabel(entry.event) "：" Logger.ResultLabel(entry.result)
                . (entry.count > 1 ? "（连续 " entry.count " 次）" : "") "`n"
        return text != "" ? RTrim(text, "`n") : "暂无诊断。"
    }
    Clear() => this.entries := []
    static EventLabel(event) {
        labels := Map("Startup", "启动", "Reload", "配置重载", "Pause", "暂停状态", "FeatureToggle", "功能开关",
            "Settings", "设置保存", "Refeed", "文本重喂", "Recover", "取回原文", "AutoSwitch", "自动切换", "Clipboard", "剪贴板")
        return labels.Has(event) ? labels[event] : event
    }
    static ResultLabel(result) {
        labels := Map("Ready", "已就绪", "Failed", "失败", "Applied", "已应用", "Rejected", "已拒绝，保留之前的配置",
            "Saved", "已保存", "Paused", "已暂停", "Resumed", "已恢复", "CandidatesReady", "已重喂，等待选择候选",
            "OriginalRecovered", "原文已取回", "NoCachedOriginal", "暂无原文缓存", "AlreadyCorrect", "已是目标模式",
            "Verified", "模式设置已确认", "NoSelection", "无选区，已跳过", "SelectionUnknown", "无法观察选区，已跳过",
            "IgnoredOtherLanguage", "其他语言，已跳过", "TextTooLong", "选区超过长度上限", "WhitespaceOnly", "选区只有空白",
            "InvalidText", "选区含不支持的字符", "SelectionChanged", "选区发生变化", "CopyTimeout", "复制选区超时",
            "Busy", "正在处理另一操作", "TargetChanged", "目标焦点变化或无法确认", "FocusChanged", "目标或启用状态变化",
            "TargetNotFocused", "无法确认目标焦点", "SendingStopped", "发送已停止", "ClipboardChanged", "保留外部新复制内容",
            "UnexpectedClipboardOwner", "无法确认复制来源", "VerificationFailed", "无法确认输入法模式",
            "ReadinessFailed", "输入法尚未稳定", "HotkeyReleaseTimeout", "修饰键释放超时", "SystemError", "系统接口失败",
            "DeleteFailed", "删除请求失败，原文缓存已保留", "SendFailed", "发送失败，原文缓存已保留",
            "RecoverFailed", "取回失败", "InputLanguageNotSupported", "当前语言不在支持范围",
            "ImeWindowUnavailable", "无法取得输入法窗口", "ImeQueryFailed", "输入法读取失败",
            "ImeWriteFailed", "输入法设置失败", "ImeOpenFailed", "开启中文模式失败", "ImeCloseFailed", "切换英文模式失败",
            "AutoSwitchFailed", "自动切换接口失败", "RestoreFailed", "剪贴板恢复失败", "ExitRestoreFailed", "退出时剪贴板恢复失败")
        return labels.Has(result) ? labels[result] : result
    }
}
