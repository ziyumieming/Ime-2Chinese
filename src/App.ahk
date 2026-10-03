#Requires AutoHotkey v2.0
#Include config\Defaults.ahk
#Include config\HotkeySpec.ahk
#Include config\ConfigStore.ahk
#Include common\Logger.ahk
#Include common\Notify.ahk
#Include system\HotkeyBindings.ahk
#Include ui\TrayMenu.ahk

class App {
    __New(store := unset, hotkeys := unset, notifier := unset) {
        this.store := IsSet(store) ? store : ConfigStore()
        this.hotkeys := IsSet(hotkeys) ? hotkeys : HotkeyBindings()
        this.notifier := IsSet(notifier) ? notifier : Notify()
        this.logger := Logger(), this.settings := Defaults.Create()
        this.paused := false, this.ready := false
        this.handlers := Map() ; Unavailable feature keys are not reserved.
        this.exitHandler := ObjBindMethod(this, "Stop")
    }

    Run(args) {
        if args.Length && args[1] = "--check" {
            ConfigStore.Parse(ConfigStore.Serialize(Defaults.Create()))
            FileAppend("IME P1 modules loaded; no config writes, hotkeys or IME operations.`n", "*")
            ExitApp(0)
        }
        if args.Length {
            FileAppend("Usage: main.ahk [--check]`n", "*")
            ExitApp(2)
        }
        if !this.Start() {
            MsgBox("配置加载失败，请检查 " this.store.path "`n程序已退出；原文件未被覆盖。", "Ime-2Chinese")
            ExitApp(1)
        }
        this.tray := TrayMenu(this)
        OnExit(this.exitHandler)
        Persistent(true)
        this.notifier.Show("配置与托盘已启动。重喂和自动切换尚未接入。")
    }

    Start() {
        try {
            candidate := this.store.Load()
            this.hotkeys.Apply(this.Bindings(candidate))
            this.settings := candidate, this.ready := true
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
            this.hotkeys.Apply(this.Bindings(candidate))
            this.settings := candidate
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
            this.hotkeys.Apply(this.Bindings(candidate))
            this.store.Save(candidate)
            this.settings := candidate
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
        this.hotkeys.Clear()
        this.ready := false
        return 0
    }
}
