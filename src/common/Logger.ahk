#Requires AutoHotkey v2.0

; Bounded operation snapshots. Content comes only from already-authorized reads.
class Logger {
    __New(limit := 30, clock := unset) {
        if limit < 1
            throw ValueError("Diagnostic capacity must be positive")
        this.limit := limit, this.entries := []
        this.nextId := 0, this.listeners := Map(), this.listenerId := 0
        this.clock := IsSet(clock) ? clock : () => FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }
    Record(event, result) {
        if !RegExMatch(event, "^[A-Za-z0-9_]+$") || !RegExMatch(result, "^[A-Za-z0-9_]+$")
            throw ValueError("Diagnostic identifiers only")
        timestamp := this.clock.Call()
        if this.entries.Length {
            previous := this.entries[this.entries.Length]
            if previous.event = event && previous.result = result && !previous.HasOwnProp("id") {
                previous.count += 1, previous.at := timestamp
                this.Notify()
                return
            }
        }
        this.entries.Push({at: timestamp, firstAt: timestamp, event: event, result: result, count: 1})
        while this.entries.Length > this.limit
            this.entries.RemoveAt(1)
        this.Notify()
    }
    Begin(event) {
        operation := {id: ++this.nextId, at: this.clock.Call(), event: event, result: "Started", count: 1,
            started: A_TickCount, steps: [], dropped: 0, duration: 0}
        operation.firstAt := operation.at
        this.entries.Push(operation)
        while this.entries.Length > this.limit
            this.entries.RemoveAt(1)
        this.Notify()
        return operation
    }
    Stage(operation, name, data := unset) {
        fields := Map()
        if IsSet(data)
            this.Fields(fields, data)
        operation.steps.Push({name: name, elapsed: A_TickCount - operation.started, fields: fields})
        if operation.steps.Length > 64
            operation.steps.RemoveAt(1), operation.dropped += 1
        operation.at := this.clock.Call()
        this.Notify()
    }
    Fields(fields, data, prefix := "") {
        if !IsObject(data)
            return
        for name, value in data.OwnProps() {
            if name = "token" || name = "ptr"
                continue
            key := prefix name
            if IsObject(value) {
                if name = "status" || name = "beforeStatus"
                    this.Fields(fields, value, key ".")
                continue
            }
            if fields.Count >= 40
                break
            key := name = "text" ? "selectedText" : key
            cap := InStr(StrLower(key), "title") ? 32768 : key = "selectedText" ? 4096 : 2048
            text := String(value)
            fields[key] := StrLen(text) > cap ? SubStr(text, 1, cap) " [已截断，原长度 " StrLen(text) "]" : text
        }
    }
    Finish(operation, result) {
        operation.result := result.reason, operation.duration := A_TickCount - operation.started
        if result.HasOwnProp("failedStage")
            operation.failedStage := result.failedStage
        this.Stage(operation, "Finish", result)
        length := this.entries.Length
        if length > 1 && this.entries[length] = operation {
            previous := this.entries[length - 1]
            if this.SameOperation(previous, operation) {
                operation.count := previous.count + 1, operation.firstAt := previous.firstAt
                operation.firstId := previous.HasOwnProp("firstId") ? previous.firstId : previous.id
                this.entries.RemoveAt(length - 1)
                this.Notify()
            }
        }
    }
    SameOperation(first, last) {
        if !first.HasOwnProp("id") || first.event != last.event || first.result != last.result || first.steps.Length != last.steps.Length
            return false
        for index, step in first.steps {
            other := last.steps[index]
            if step.name != other.name || step.fields.Count != other.fields.Count
                return false
            for key, value in step.fields {
                if key != "operationId" && (!other.fields.Has(key) || other.fields[key] != value)
                    return false
            }
        }
        return true
    }
    Subscribe(callback) {
        id := ++this.listenerId
        this.listeners[id] := callback
        return id
    }
    Unsubscribe(id) {
        if this.listeners.Has(id)
            this.listeners.Delete(id)
    }
    Notify() {
        for id, callback in this.listeners.Clone()
            try callback.Call()
    }
    Recent() {
        text := ""
        for entry in this.entries {
            text .= entry.at "  " Logger.EventLabel(entry.event) "：" Logger.ResultLabel(entry.result)
                . (entry.count > 1 ? "（连续 " entry.count " 次）" : "") "`n"
            if entry.count > 1
                text .= "  首次：" entry.firstAt "；最近：" entry.at "`n"
            if entry.HasOwnProp("id") {
                text .= "  操作 #" entry.id "；耗时 " entry.duration " ms`n"
                if entry.HasOwnProp("firstId")
                    text .= "  相同内容/目标的操作 #" entry.firstId "–#" entry.id "，保留最近一次步骤。`n"
                if entry.HasOwnProp("failedStage")
                    text .= "  停止阶段：" Logger.StageLabel(entry.failedStage) "；以下为观察结果，不能据此确定根因。`n"
                for step in entry.steps {
                    text .= "  +" step.elapsed " ms " Logger.StageLabel(step.name) " [" step.name "]`n"
                    for key, value in step.fields
                        text .= "    " key "=" StrReplace(StrReplace(value, "`r", "\r"), "`n", "\n") "`n"
                }
                if entry.dropped
                    text .= "  [省略较早的 " entry.dropped " 个步骤]`n"
            }
        }
        return text != "" ? RTrim(text, "`n") : "暂无诊断。"
    }
    Clear() {
        this.entries := []
        this.Notify()
    }
    static EventLabel(event) {
        labels := Map("Startup", "启动", "Reload", "配置重载", "Pause", "暂停状态", "FeatureToggle", "功能开关",
            "Settings", "设置保存", "Refeed", "文本重喂", "Recover", "取回原文", "AutoSwitch", "自动切换", "Clipboard", "剪贴板")
        return labels.Has(event) ? labels[event] : event
    }
    static StageLabel(stage) {
        labels := Map("CaptureTarget", "捕获目标", "EditableCheck", "检查可编辑性", "ReleaseKeys", "等待触发键释放",
            "LanguageCheck", "检查输入语言", "SelectionCheck", "检查选区", "ClipboardBegin", "备份剪贴板",
            "CopySelection", "复制选区", "ValidateText", "校验选中文本", "RequestedMode", "请求中文模式",
            "PrepareIme", "准备输入法", "VerifySelection", "再次核对选区", "ReadyBeforeDelete", "删除前等待中文稳定",
            "SelectionBeforeDelete", "删除前检查选区", "DeleteAttempt", "缓存原文及准备删除", "DeleteSelection", "删除选区",
            "ReadyAfterDelete", "删除后等待中文稳定", "SendLetters", "逐字发送", "SendOriginal", "取回原文",
            "ClipboardCleanup", "清理剪贴板", "TargetGuard", "复核目标", "Exception", "接口异常", "Finish", "操作结果")
        return labels.Has(stage) ? labels[stage] : stage
    }
    static ResultLabel(result) {
        labels := Map("Ready", "已就绪", "Failed", "失败", "Applied", "已应用", "Rejected", "已拒绝，保留之前的配置",
            "Started", "正在执行", "EditableUnknown", "无法确认可编辑性，已跳过", "ReadOnlyTarget", "只读位置，已跳过",
            "PasswordTarget", "密码框，已跳过", "TargetDisabled", "输入框禁用，已跳过", "NonEditableTarget", "非文本输入位置，已跳过",
            "TerminalUnsupported", "终端尚未兼容，已跳过",
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
