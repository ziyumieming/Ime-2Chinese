#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk

class FakeHotkeys {
    __New() {
        this.active := Map(), this.failKey := ""
    }
    Enable(key, callback) {
        if key = this.failKey
            throw Error("Simulated registration failure")
        this.active[key] := callback
    }
    Disable(key) {
        if this.active.Has(key)
            this.active.Delete(key)
    }
}
class FakeStore {
    __New() {
        this.value := Defaults.Create(), this.badLoad := false, this.badSave := false
    }
    Load(*) {
        if this.badLoad
            throw Error("Simulated invalid config")
        return ConfigStore.Parse(ConfigStore.Serialize(this.value))
    }
    Save(settings) {
        if this.badSave
            throw Error("Simulated disk failure")
        this.value := ConfigStore.Parse(ConfigStore.Serialize(settings))
    }
}
class QuietNotify {
    Show(*) {
    }
}

RunTests()
RunTests() {
    try {
        store := FakeStore(), driver := FakeHotkeys()
        application := App(store, HotkeyBindings(driver), QuietNotify())
        TestAssert.Equal(application.Start(), true, "start succeeds")
        TestAssert.Equal(driver.active.Count, 0, "unimplemented features reserve no keys")
        application.handlers["refeed"] := (*) => 0
        application.handlers["recover"] := (*) => 0
        TestAssert.Equal(application.Reload(), true, "attach handlers through reload")
        TestAssert.Equal(driver.active.Count, 2, "both feature hotkeys registered")
        TestAssert.Equal(application.TogglePause(), true, "pause succeeds")
        TestAssert.Equal(driver.active.Count, 0, "paused unregisters all keys")
        TestAssert.Equal(application.TogglePause(), true, "resume succeeds")
        TestAssert.Equal(driver.active.Count, 2, "resume registers once")
        store.badLoad := true
        TestAssert.Equal(application.Reload(), false, "invalid reload rejected")
        TestAssert.Equal(driver.active.Has("!z"), true, "old key retained after bad config")
        store.badLoad := false
        store.value.refeedHotkey := "^!x"
        ; Use a new recover key for a one-time failure, allowing old keys to restore.
        store.value.recoverHotkey := "^!y", driver.failKey := "^!y"
        TestAssert.Equal(application.Reload(), false, "partial registration fails")
        TestAssert.Equal(driver.active.Count, 2, "rollback restores old registrations")
        TestAssert.Equal(driver.active.Has("^!x"), false, "partial new key removed")
        TestAssert.Equal(application.settings.refeedHotkey, "!z", "old effective config retained")
        driver.failKey := ""
        TestAssert.Equal(application.Reload(), true, "valid retry succeeds")
        TestAssert.Equal(driver.active.Has("!z"), false, "old key removed on successful reload")
        TestAssert.Equal(driver.active.Has("^!x"), true, "new key active")
        store.badSave := true
        TestAssert.Equal(application.ToggleFeature("enableRefeed"), false, "failed save rejected")
        TestAssert.Equal(application.settings.enableRefeed, true, "feature preference restored")
        TestAssert.Equal(driver.active.Count, 2, "failed save restores hotkeys")
        store.badSave := false
        store.value.sendIntervalMs := 37 ; A file edit not yet reloaded.
        TestAssert.Equal(application.ToggleFeature("enableRefeed"), true, "disable feature saved")
        TestAssert.Equal(store.value.sendIntervalMs, 37, "pending edits survive tray save")
        TestAssert.Equal(application.settings.sendIntervalMs, 37, "valid file edits applied with toggle")
        TestAssert.Equal(driver.active.Count, 0, "disable removes hotkeys")
        TestAssert.Equal(store.value.enableRefeed, false, "disabled preference persisted")
        TestAssert.Equal(application.ToggleFeature("enableRefeed"), true, "enable feature saved")
        application.Stop()
        TestAssert.Equal(driver.active.Count, 0, "exit cleanup removes all keys")
        application.Stop()
        TestAssert.Equal(driver.active.Count, 0, "cleanup can repeat")
        history := Logger(2)
        history.Record("One", "OK"), history.Record("Two", "OK"), history.Record("Three", "OK")
        TestAssert.Equal(history.entries.Length, 2, "diagnostic history bounded")
        TestAssert.Equal(InStr(history.Recent(), "One"), 0, "oldest diagnostic evicted")
        TestAssert.Throws(() => history.Record("input text", "OK"), "arbitrary text not logged")
        TestAssert.Finish("lifecycle, pause, reload rollback, feature persistence and diagnostics")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
