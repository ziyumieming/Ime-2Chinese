#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk

class SettingsStore {
    __New() => (this.value := Defaults.Create(), this.saves := 0, this.failSave := false, this.onSave := (*) => 0)
    Load(*) => SettingsModel.Clone(this.value)
    Save(settings) {
        this.onSave.Call()
        if this.failSave
            throw Error("private disk failure")
        this.value := SettingsModel.Clone(settings), this.saves += 1
    }
}
class SettingsBindings {
    __New() => (this.failNext := false, this.calls := 0)
    Apply(*) {
        this.calls += 1
        if this.failNext {
            this.failNext := false
            throw Error("binding failure")
        }
    }
    Clear() {
    }
}
class SettingsNotice {
    __New() => this.count := 0
    Show(*) => this.count += 1
}
class SettingsTimer {
    __New() => (this.interval := 0, this.failNext := false)
    Start(callback, interval) {
        if this.failNext {
            this.failNext := false
            throw Error("timer failure")
        }
        this.interval := interval
    }
    Stop(*) => this.interval := 0
}
class SettingsContext {
    Capture() => {hwnd: 1, processId: 5, processName: "notepad.exe", title: "private title"}
}
class SettingsIme {
    __New() => this.calls := 0
    EnsureMode(*) => (this.calls += 1, {ok: true, reason: "Verified"})
}
RunTests()
RunTests() {
try {
    store := SettingsStore(), bindings := SettingsBindings(), timer := SettingsTimer(), ime := SettingsIme()
    store.value.rules := [{id: "N", process: "notepad.exe", titleContains: "", mode: "Chinese"}]
    notice := SettingsNotice(), application := App(store, bindings, notice)
    application.AttachAuto({contexts: SettingsContext(), ime: ime}, timer)
    application.Start()
    baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline)
    values.sendIntervalMs := 25, values.refeedHotkey := "Ctrl+Alt+F8"
    store.value.rules[1].mode := "Ignore", store.value.maxRefeedLength := 75
    store.onSave := (*) => TestAssert.Equal(application.gate.owner, "Settings", "save owns shared coordinator")
    result := application.SaveSettings(baseline, values)
    TestAssert.Equal(result.ok, true, "save applies")
    TestAssert.Equal(store.saves, 1, "one disk save")
    TestAssert.Equal(application.settings.refeedHotkey, "^!f8", "normalized key effective")
    TestAssert.Equal(application.settings.maxRefeedLength, 75, "unrelated external preference kept")
    TestAssert.Equal(application.rules.Match(SettingsContext().Capture()).mode, "Ignore", "pending rules compiled")
    TestAssert.Equal(application.gate.owner, "", "save gate released")
    TestAssert.Equal(ime.calls, 1, "saving preferences does not force mode")
    baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline)
    values.pollIntervalMs := 800, store.failSave := true, previousRules := application.rules
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "disk failure rejected")
    TestAssert.Equal(timer.interval, 300, "disk failure restores timer")
    TestAssert.Equal(application.settings.pollIntervalMs, 300, "disk failure retains effective preference")
    TestAssert.Equal(application.rules = previousRules, true, "disk failure retains engine")
    TestAssert.Equal(application.gate.owner, "", "failure releases gate")
    store.failSave := false, timer.failNext := true
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "timer failure rejected")
    TestAssert.Equal(store.saves, 1, "timer failure does not save")
    bindings.failNext := true
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "hotkey failure rejected")
    TestAssert.Equal(store.saves, 1, "hotkey failure does not save")
    values.maxRefeedLength := 0
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "invalid draft rejected")
    values := SettingsModel.Values(baseline), values.sendIntervalMs := 40, store.value.sendIntervalMs := 30
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "file conflict rejected")
    TestAssert.Equal(store.value.sendIntervalMs, 30, "conflicting file untouched")
    store.value.sendIntervalMs := baseline.sendIntervalMs
    application.gate.TryEnter("Manual")
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "manual operation blocks save")
    TestAssert.Equal(store.saves, 1, "busy save touches no disk")
    application.gate.Leave("Manual")
    application.TogglePause()
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, true, "paused settings can save")
    TestAssert.Equal(timer.interval, 0, "save does not unpause timer")
    TestAssert.Equal(application.paused, true, "pause retained")
    application.TogglePause()
    baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline), values.enableAutoSwitch := 0
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, true, "disable auto via settings")
    TestAssert.Equal(timer.interval, 0, "disable stops timer")
    baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline), values.enableAutoSwitch := 1
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, true, "enable auto via settings")
    TestAssert.Equal(timer.interval, 300, "enable starts timer")
    TestAssert.Equal(ime.calls, 1, "Ignore rule remains untouched on enable")
    baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline)
    saved := store.saves, application.SaveSettings(baseline, values)
    TestAssert.Equal(store.saves, saved, "unchanged draft applies without rewriting file")
    modeCount := ime.calls, recordCount := application.logger.entries.Length, noticeCount := notice.count
    loop 10000
        application.auto.Tick()
    TestAssert.Equal(ime.calls, modeCount, "10000 idle checks do not repeat IME writes")
    TestAssert.Equal(application.logger.entries.Length, recordCount, "idle checks do not fill diagnostics")
    TestAssert.Equal(notice.count, noticeCount, "idle checks do not notify")
    TestAssert.Equal(InStr(application.logger.Recent(), "private"), 0, "errors and window titles excluded from diagnostics")
    application.Stop()
    TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "stopped app cannot save")
    TestAssert.Finish("settings transaction, rollback, pending rules, busy and pause")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
    ExitApp(1)
}
}
