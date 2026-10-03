#Requires AutoHotkey v2.0
#Include config\Defaults.ahk
#Include config\HotkeySpec.ahk
#Include config\ConfigStore.ahk
#Include common\Logger.ahk
#Include common\Notify.ahk
#Include system\HotkeyBindings.ahk
#Include ui\TrayMenu.ahk
#Include common\TextRules.ahk
#Include system\WindowContext.ahk
#Include system\ImeProfiles.ahk
#Include system\ImeController.ahk
#Include system\ClipboardService.ahk
#Include system\TextSender.ahk
#Include system\InputRuntime.ahk
#Include features\RefeedFeature.ahk
#Include rules\RuleEngine.ahk

class App {
    __New(store := unset, hotkeys := unset, notifier := unset) {
        this.store := IsSet(store) ? store : ConfigStore()
        this.hotkeys := IsSet(hotkeys) ? hotkeys : HotkeyBindings()
        this.notifier := IsSet(notifier) ? notifier : Notify()
        this.logger := Logger(), this.settings := Defaults.Create()
        this.rules := RuleEngine(this.settings.rules)
        this.paused := false, this.ready := false
        this.testMode := false
        this.handlers := Map() ; Unavailable feature keys are not reserved.
        this.exitHandler := ObjBindMethod(this, "Stop")
    }

    Run(args) {
        if args.Length && args[1] = "--check" {
            ConfigStore.Parse(ConfigStore.Serialize(Defaults.Create()))
            RuleEngine(Defaults.Create().rules)
            FileAppend("IME P1/P2/P3 modules loaded; no config writes, hotkeys or IME operations.`n", "*")
            ExitApp(0)
        }
        if args.Length {
            if args.Length = 1 && args[1] = "--test-refeed" {
                this.testMode := true
                this.AttachRefeed({contexts: NativeInputContext(), keys: TriggerKeys(),
                    clipboard: ClipboardService(), ime: ImeController(), sender: TextSender()})
            } else {
                FileAppend("Usage: main.ahk [--check | --test-refeed]`n", "*")
                ExitApp(2)
            }
        }
        if !this.Start() {
            MsgBox("配置加载失败，请检查 " this.store.path "`n程序已退出；原文件未被覆盖。", "Ime-2Chinese")
            ExitApp(1)
        }
        this.tray := TrayMenu(this)
        OnExit(this.exitHandler)
        Persistent(true)
        this.notifier.Show(this.testMode ? "重喂 MVP 测试已启动，请在无候选的人工测试文本上使用。"
            : "配置与托盘已启动。重喂需显式启动测试版；自动切换尚未接入。")
    }

    AttachRefeed(adapters) {
        this.refeed := RefeedFeature(() => this.settings, adapters,
            () => this.ready && !this.paused && this.settings.enableRefeed)
        this.handlers["refeed"] := (*) => this.RunInputAction(false)
        this.handlers["recover"] := (*) => this.RunInputAction(true)
    }

    RunInputAction(recover) {
        result := recover ? this.refeed.RecoverLast() : this.refeed.ConvertSelection()
        this.logger.Record(recover ? "Recover" : "Refeed", result.reason)
        messages := Map("CandidatesReady", "重喂完成，请自行选择候选。", "OriginalRecovered", "原文已取回。",
            "NoSelection", "没有取得选区。", "TextTooLong", "选区超过长度上限。",
            "InvalidText", "只支持英文字母和空白。", "WhitespaceOnly", "选区没有英文字母。",
            "NoCachedOriginal", "暂无可取回的原文。", "TargetImeNotActive", "请先启用配置指定的中文输入法，再重新选择文本。",
            "SelectionChanged", "输入法切换后选区发生变化，本次未删除文本。",
            "CopyTimeout", "复制选区超时，本次未删除文本。",
            "Busy", "正在处理上一次操作。", "Paused", "功能已暂停。",
            "TargetChanged", "目标焦点已变化或无法确认，本次停止。",
            "SendingStopped", "目标或启用状态已变化，后续输入已停止。",
            "ClipboardChanged", "剪贴板已更新，本次停止并保留新内容。",
            "UnexpectedClipboardOwner", "无法确认复制内容来自目标应用，本次停止。",
            "VerificationFailed", "未能确认输入法模式，本次停止。",
            "FocusChanged", "切换输入法时目标焦点发生变化，本次停止。",
            "TargetNotFocused", "目标没有可确认的焦点，本次停止。",
            "HotkeyReleaseTimeout", "热键修饰键未及时释放，本次停止。")
        message := messages.Has(result.reason) ? messages[result.reason] : "操作失败，请查看最近诊断。"
        if !result.ok && result.HasOwnProp("changed") && result.changed
            message .= " 原文缓存已保留，可用取回原文热键插入。"
        if result.HasOwnProp("clipboardReason") && result.clipboardReason = "ClipboardRestoreFailed" {
            this.logger.Record("Clipboard", "RestoreFailed")
            message .= " 剪贴板未能恢复。"
        }
        this.notifier.Show(message)
        return result
    }

    Start() {
        try {
            candidate := this.store.Load()
            candidateRules := RuleEngine(candidate.rules)
            this.hotkeys.Apply(this.Bindings(candidate))
            this.settings := candidate, this.rules := candidateRules, this.ready := true
            this.logger.Record("Startup", "Ready")
            return true
        } catch as err {
            this.logger.Record("Startup", "Failed")
            this.notifier.Show("启动失败：" err.Message)
            return false
        }
    }

    Bindings(settings) {
        bindings := []
        if !this.paused && settings.enableRefeed {
            if this.handlers.Has("refeed")
                bindings.Push({key: settings.refeedHotkey, callback: this.handlers["refeed"]})
            if this.handlers.Has("recover")
                bindings.Push({key: settings.recoverHotkey, callback: this.handlers["recover"]})
        }
        return bindings
    }

    Reload() {
        try {
            candidate := this.store.Load(false)
            candidateRules := RuleEngine(candidate.rules)
            this.hotkeys.Apply(this.Bindings(candidate))
            this.settings := candidate, this.rules := candidateRules
            this.logger.Record("Reload", "Applied")
            this.RefreshTray()
            this.notifier.Show("配置已重载。")
            return true
        } catch as err {
            this.logger.Record("Reload", "Rejected")
            this.notifier.Show("重载失败，保留上一次有效配置：" err.Message)
            return false
        }
    }

    TogglePause() {
        previous := this.paused
        this.paused := !previous
        try this.hotkeys.Apply(this.Bindings(this.settings))
        catch {
            this.paused := previous
            this.notifier.Show("暂停状态变更失败。")
            return false
        }
        this.logger.Record("Pause", this.paused ? "Paused" : "Resumed")
        this.RefreshTray()
        return true
    }

    ToggleFeature(name) {
        if name != "enableRefeed" && name != "enableAutoSwitch"
            throw ValueError("Unknown feature")
        try {
            ; Read the file first so a tray toggle cannot overwrite pending edits.
            candidate := this.store.Load(false)
            candidate.%name% := !this.settings.%name%
            candidateRules := RuleEngine(candidate.rules)
            this.hotkeys.Apply(this.Bindings(candidate))
            this.store.Save(candidate)
            this.settings := candidate, this.rules := candidateRules
        } catch as err {
            try this.hotkeys.Apply(this.Bindings(this.settings))
            this.notifier.Show("开关保存失败，保留之前的配置：" err.Message)
            return false
        }
        this.logger.Record("FeatureToggle", "Saved")
        this.RefreshTray()
        return true
    }

    OpenConfig() => Run('notepad.exe "' this.store.path '"')

    RefreshTray() {
        if this.HasOwnProp("tray")
            this.tray.Refresh()
    }

    Stop(*) {
        this.ready := false
        this.hotkeys.Clear()
        if this.HasOwnProp("refeed") {
            try this.refeed.adapters.clipboard.End()
            catch
                this.logger.Record("Clipboard", "ExitRestoreFailed")
            this.refeed.lastOriginal := ""
        }
        return 0
    }
}
