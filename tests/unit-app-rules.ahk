#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk

class RuleStore {
    __New() => this.text := "[Rule.notes]`nProcess=notepad.exe`nMode=Chinese"
    Load(*) => ConfigStore.Parse(this.text)
    Save(settings) {
        if this.HasOwnProp("failSave") && this.failSave
            throw Error("simulated save failure")
        this.text := ConfigStore.Serialize(settings)
    }
}
class RuleHotkeys {
    Apply(*) {
        if this.HasOwnProp("failApply") && this.failApply
            throw Error("simulated binding failure")
    }
    Clear() {
    }
}
class RuleNotify {
    Show(*) {
    }
}

RunTests()
RunTests() {
    try {
        store := RuleStore(), bindings := RuleHotkeys()
        application := App(store, bindings, RuleNotify())
        target := {processName: "notepad.exe", title: "personal title"}
        TestAssert.Equal(application.rules.Match(target).mode, "NoMatch", "empty engine before startup")
        TestAssert.Equal(application.Start(), true, "config and engine start together")
        first := application.rules.Match(target)
        TestAssert.Equal(first.mode, "Chinese", "startup compiles loaded rules")
        TestAssert.Equal(application.handlers.Count, 0, "no auto or input handlers attached")
        store.text := "[Rule.unrelated]`nProcess=other.exe`nMode=English`n"
            . "[Rule.notes]`nProcess=notepad.exe`nMode=Chinese"
        TestAssert.Equal(application.Reload(), true, "valid unrelated rule reload")
        TestAssert.Equal(RuleEngine.SameMatch(first, application.rules.Match(target)), true, "unrelated reload keeps match stable")
        previous := application.rules
        store.text := "[Rule.notes]`nProcess=notepad.exe`nMode=English", bindings.failApply := true
        TestAssert.Equal(application.Reload(), false, "binding failure rejects entire candidate")
        TestAssert.Equal(application.rules = previous, true, "failed binding preserves effective engine")
        TestAssert.Equal(application.settings.rules[2].mode, "Chinese", "failed binding preserves effective settings")
        bindings.failApply := false
        TestAssert.Equal(application.Reload(), true, "retry applies valid candidate")
        TestAssert.Equal(application.rules.Match(target).mode, "English", "effective action changes on reload")
        TestAssert.Equal(RuleEngine.SameMatch(first, application.rules.Match(target)), false, "same-ID changed action detectable")
        previous := application.rules
        store.text := "[Rule.notes]`nProcess=notepad.exe`nMode=Bad"
        TestAssert.Equal(application.Reload(), false, "invalid config rejected")
        TestAssert.Equal(application.rules = previous, true, "invalid config preserves engine")
        store.text := "[Rule.notes]`nProcess=notepad.exe`nMode=Ignore", store.failSave := true
        TestAssert.Equal(application.ToggleFeature("enableRefeed"), false, "disk failure rejects pending rules and preference")
        TestAssert.Equal(application.rules = previous, true, "disk failure preserves effective engine")
        TestAssert.Equal(application.settings.enableRefeed, true, "disk failure preserves preference")
        store.failSave := false
        TestAssert.Equal(application.ToggleFeature("enableRefeed"), true, "toggle applies pending valid edits")
        TestAssert.Equal(application.rules.Match(target).mode, "Ignore", "pending rules compiled with toggle")
        TestAssert.Equal(application.settings.enableRefeed, false, "preference and engine consistent")
        TestAssert.Equal(InStr(application.logger.Recent(), "personal title"), 0, "no observed title in log")
        TestAssert.Equal(InStr(application.logger.Recent(), "notepad.exe"), 0, "rule contents not logged")
        application.Stop()
        TestAssert.Equal(application.ready, false, "stopped with no listener to cancel")
        TestAssert.Finish("rule compilation, atomic reload/save rollback and privacy")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
