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
#Include system\SelectionProbe.ahk
#Include features\AutoSwitchFeature.ahk
#Include config\SettingsModel.ahk
#Include ui\SettingsWindow.ahk
#Include ui\DiagnosticsWindow.ahk
#Include system\StartupService.ahk
#Include system\HotkeyRecorder.ahk
#Include config\AppInfo.ahk
#Include system\PackageCheck.ahk

class App {
    __New(store := unset, hotkeys := unset, notifier := unset, startup := unset) {
        this.store := IsSet(store) ? store : ConfigStore()
        this.hotkeys := IsSet(hotkeys) ? hotkeys : HotkeyBindings()
        this.notifier := IsSet(notifier) ? notifier : Notify()
        this.startup := IsSet(startup) ? startup : StartupService()
        this.logger := Logger(), this.settings := Defaults.Create()
        this.rules := RuleEngine(this.settings.rules)
        this.paused := false, this.ready := false
        this.applying := false, this.gate := InputCoordinator()
        this.testMode := false
        this.recordingHotkey := false
        this.handlers := Map() ; Unavailable feature keys are not reserved.
        this.exitHandler := ObjBindMethod(this, "Stop")
    }

    Run(args) {
        if args.Length = 1 && args[1] = "--self-test" {
            PackageCheck.Run()
            return
        }
        if args.Length && args[1] = "--check" {
            ConfigStore.Parse(ConfigStore.Serialize(Defaults.Create()))
            RuleEngine(Defaults.Create().rules)
            FileAppend("IME P1/P2/P3/P4/P5 modules loaded; no config writes, hotkeys or IME operations.`n", "*")
            ExitApp(0)
        }
        if !args.Length {
            this.AttachManualInput()
        } else {
            if args.Length = 1 && (args[1] = "--test-refeed" || args[1] = "--test-all") {
                this.testMode := true
                this.AttachManualInput()
                if args[1] = "--test-all"
                    this.AttachAuto({contexts: NativeInputContext(), ime: ImeController()})
            } else if !(args.Length = 1 && args[1] = "--settings-only") {
                FileAppend("Usage: Ime-2Chinese [--check | --self-test | --settings-only | --test-refeed | --test-all]`n", "*")
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
        this.notifier.Show(this.testMode ? "功能测试已启动，请使用无候选的人工测试文本；窗口自动切换已暂停开发。"
            : this.HasOwnProp("refeed") ? "Ime-2Chinese 已启动，可在输入框中重喂并取回原文。"
            : "设置与托盘已启动。")
    }

    AttachManualInput() {
        this.AttachRefeed({contexts: NativeInputContext(), keys: TriggerKeys(),
            clipboard: ClipboardService(), ime: ImeController(), sender: TextSender(), selection: SelectionProbe()})
    }

    AttachRefeed(adapters) {
        adapters.gate := this.gate
        adapters.logger := this.logger
        this.refeed := RefeedFeature(() => this.settings, adapters,
            () => this.ready && !this.paused && !this.recordingHotkey && this.settings.enableRefeed)
        this.handlers["refeed"] := (*) => this.RunInputAction(false)
        this.handlers["recover"] := (*) => this.RunInputAction(true)
        if this.HasOwnProp("auto")
            this.refeed.onFinish := (outcome, context) => this.auto.ObserveManual(outcome, context)
    }

    AttachAuto(adapters, scheduler := unset) {
        adapters.gate := this.gate
        this.auto := AutoSwitchFeature(() => this.settings, () => this.rules, adapters,
            () => this.ready && !this.paused && !this.applying && this.settings.enableAutoSwitch)
        this.scheduler := IsSet(scheduler) ? scheduler : PollScheduler()
        this.autoTick := ObjBindMethod(this.auto, "Tick")
        this.auto.onResult := (result) => this.logger.Record("AutoSwitch", result.reason)
        if this.HasOwnProp("refeed")
            this.refeed.onFinish := (outcome, context) => this.auto.ObserveManual(outcome, context)
    }

    RunInputAction(recover) {
        result := recover ? this.refeed.RecoverLast() : this.refeed.ConvertSelection()
        if !result.HasOwnProp("operationId")
            this.logger.Record(recover ? "Recover" : "Refeed", result.reason)
        if RegExMatch(result.reason, "^(NoSelection|IgnoredOtherLanguage|SelectionUnknown|EditableUnknown|ReadOnlyTarget|PasswordTarget|TargetDisabled|NonEditableTarget|TerminalUnsupported)$")
            return result
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
            "ReadinessFailed", "输入法尚未稳定，本次停止。",
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
            this.ApplyCandidate(candidate, candidateRules)
            this.ready := true
            if this.HasOwnProp("auto")
                this.auto.Reevaluate()
            this.logger.Record("Startup", "Ready")
            return true
        } catch as err {
            this.ready := false
            try this.hotkeys.Clear()
            if this.HasOwnProp("auto")
                try this.scheduler.Stop(this.autoTick)
            this.logger.Record("Startup", "Failed")
            this.notifier.Show("启动失败：" err.Message)
            return false
        }
    }

    Bindings(settings) {
        bindings := []
        if !this.paused && !this.recordingHotkey && settings.enableRefeed {
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
            this.ApplyCandidate(candidate, candidateRules)
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
        try {
            this.hotkeys.Apply(this.Bindings(this.settings))
            this.ConfigureAutoTimer(this.settings)
        }
        catch {
            this.paused := previous
            try this.hotkeys.Apply(this.Bindings(this.settings))
            try this.ConfigureAutoTimer(this.settings)
            this.notifier.Show("暂停状态变更失败。")
            return false
        }
        if !this.paused && this.HasOwnProp("auto")
            this.auto.Reevaluate()
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
            wasAutoEnabled := this.settings.enableAutoSwitch
            this.ApplyCandidate(candidate, candidateRules, true)
            if !wasAutoEnabled && candidate.enableAutoSwitch && this.HasOwnProp("auto")
                this.auto.Reevaluate()
        } catch as err {
            try this.hotkeys.Apply(this.Bindings(this.settings))
            this.notifier.Show("开关保存失败，保留之前的配置：" err.Message)
            return false
        }
        this.logger.Record("FeatureToggle", "Saved")
        this.RefreshTray()
        return true
    }

    ApplyCandidate(candidate, candidateRules, persist := false) {
        this.applying := true
        startupSnapshot := unset
        try {
            this.hotkeys.Apply(this.Bindings(candidate))
            this.ConfigureAutoTimer(candidate)
            if candidate.startWithWindows || candidate.startWithWindows != this.settings.startWithWindows {
                startupSnapshot := this.startup.Snapshot()
                mode := this.HasOwnProp("auto") ? "--test-all"
                    : this.HasOwnProp("refeed") ? (this.testMode ? "--test-refeed" : "") : "--settings-only"
                this.startup.Apply(candidate.startWithWindows, mode)
            }
            if persist
                this.store.Save(candidate)
            wasAutoEnabled := this.settings.enableAutoSwitch
            this.settings := candidate, this.rules := candidateRules
            if this.HasOwnProp("auto") {
                this.auto.ConfigChanged()
                if !wasAutoEnabled && candidate.enableAutoSwitch
                    this.auto.RequestReevaluation()
            }
        } catch as err {
            startupRollbackError := ""
            if IsSet(startupSnapshot) {
                try this.startup.Restore(startupSnapshot)
                catch as restoreError
                    startupRollbackError := restoreError.Message
            }
            try this.hotkeys.Apply(this.Bindings(this.settings))
            if this.ready {
                try this.ConfigureAutoTimer(this.settings)
            } else if this.HasOwnProp("auto") {
                try this.scheduler.Stop(this.autoTick)
            }
            if startupRollbackError != ""
                throw Error(err.Message "；自启回滚失败：" startupRollbackError)
            throw err
        } finally {
            this.applying := false
        }
    }

    ConfigureAutoTimer(settings) {
        if !this.HasOwnProp("auto")
            return
        if settings.enableAutoSwitch && !this.paused
            this.scheduler.Start(this.autoTick, settings.pollIntervalMs)
        else
            this.scheduler.Stop(this.autoTick)
    }


    SaveSettings(baseline, values) {
        if !this.ready
            return {ok: false, message: "程序尚未就绪，未保存设置。"}
        if this.applying || this.gate.owner != ""
            return {ok: false, message: "正在处理输入或配置，请稍后再次保存。"}
        if !this.gate.TryEnter("Settings")
            return {ok: false, message: "正在处理输入或配置，请稍后再次保存。"}
        ; The file may have changed while the settings window was open.
        try {
            latest := this.store.Load(false)
            merged := SettingsModel.Merge(baseline, values, latest)
            candidate := merged.settings, candidateRules := RuleEngine(candidate.rules)
            wasAutoEnabled := this.settings.enableAutoSwitch
            this.ApplyCandidate(candidate, candidateRules, merged.changes > 0)
            this.logger.Record("Settings", "Saved")
            this.RefreshTray()
            result := {ok: true, message: "已保存并应用。" (this.paused ? "当前仍暂停。" : ""), settings: SettingsModel.Clone(this.settings)}
        } catch as err {
            this.logger.Record("Settings", "Rejected")
            result := {ok: false, message: "未保存，保留之前的运行配置：" err.Message}
        } finally {
            this.gate.Leave("Settings")
        }
        if result.ok && !wasAutoEnabled && this.settings.enableAutoSwitch && this.HasOwnProp("auto")
            this.auto.Reevaluate()
        return result
    }

    InputAvailability() {
        if this.HasOwnProp("auto")
            return "历史全功能入口：重喂、取回及已冻结的自动切换；旧配置保持兼容。"
        return this.HasOwnProp("refeed") ? (this.testMode ? "重喂测试入口" : "正式入口") "：已接入重喂与取回；无后台窗口检查。"
            : "当前为设置与托盘入口；输入功能需显式启动测试入口。"
    }

    OpenSettings() {
        if !this.HasOwnProp("settingsWindow")
            this.settingsWindow := SettingsWindow(this)
        this.settingsWindow.Show()
    }
    BeginHotkeyCapture() {
        if !this.ready || this.applying || this.gate.owner != "" || this.recordingHotkey
            return false
        this.hotkeys.Apply([])
        this.recordingHotkey := true
        return true
    }
    EndHotkeyCapture() {
        this.recordingHotkey := false
        if this.ready
            this.hotkeys.Apply(this.Bindings(this.settings))
    }

    OpenDiagnostics() {
        if !this.HasOwnProp("diagnosticsWindow")
            this.diagnosticsWindow := DiagnosticsWindow(this)
        this.diagnosticsWindow.Show()
    }

    DiagnosticSummary() {
        return "运行状态：" (!this.ready ? "未启动" : this.paused ? "已暂停" : "运行中") "`n"
            . this.InputAvailability() "`n重喂偏好：" (this.settings.enableRefeed ? "启用" : "关闭")
            . "；历史自动切换偏好（已冻结）：" (this.settings.enableAutoSwitch ? "启用" : "关闭")
            . "`n快捷键：" SettingsModel.DisplayHotkey(this.settings.refeedHotkey) " / " SettingsModel.DisplayHotkey(this.settings.recoverHotkey)
            . "`n版本：" AppInfo.Version (A_IsCompiled ? "；独立 EXE" : "；源码运行") "；AutoHotkey " A_AhkVersion
            . "`n记录保存在内存；含操作取得的选中文本和完整窗口标题。可主动导出；不额外复制或读取整框内容。`n`n" this.logger.Recent()
    }

    RefreshTray() {
        if this.HasOwnProp("tray")
            this.tray.Refresh()
    }

    Stop(*) {
        this.ready := false
        for name in ["settingsWindow", "diagnosticsWindow"] {
            if this.HasOwnProp(name) {
                try this.%name%.Close()
                this.DeleteProp(name)
            }
        }
        if this.HasOwnProp("auto")
            this.scheduler.Stop(this.autoTick)
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
