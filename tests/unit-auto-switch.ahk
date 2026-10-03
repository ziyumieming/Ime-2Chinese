#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\features\AutoSwitchFeature.ahk
#Include TestAssert.ahk

class AutoContext {
    __New() => this.value := {hwnd: 10, processId: 100, processName: "browser.exe", title: "中文 - before", titleKnown: true}
    Capture() => this.value.Clone()
}
class AutoIme {
    __New() {
        this.calls := [], this.fail := false, this.throwOnce := false
    }
    EnsureMode(hwnd, mode, *) {
        this.calls.Push([hwnd, mode])
        if this.throwOnce {
            this.throwOnce := false
            throw Error("provider failed")
        }
        return {ok: !this.fail, reason: this.fail ? "VerificationFailed" : "Verified"}
    }
}
class AutoFixture {
    __New() {
        this.enabled := true, this.contexts := AutoContext(), this.ime := AutoIme(), this.gate := InputCoordinator()
        this.definitions := [{id: "Ignore", process: "browser.exe", titleContains: "private", mode: "Ignore"},
            {id: "ChineseA", process: "browser.exe", titleContains: "中文", mode: "Chinese"},
            {id: "ChineseB", process: "browser.exe", titleContains: "Chinese", mode: "Chinese"},
            {id: "Default", process: "browser.exe", titleContains: "", mode: "English"}]
        this.engine := RuleEngine(this.definitions)
        this.feature := AutoSwitchFeature(() => {}, () => this.engine,
            {contexts: this.contexts, ime: this.ime, gate: this.gate}, () => this.enabled)
    }
}
RunTests()
RunTests() {
    try {
        fixture := AutoFixture()
        TestAssert.Equal(fixture.feature.Tick().ok, true, "startup applies once")
        TestAssert.Equal(fixture.ime.calls[1][2], "Chinese", "startup mode")
        fixture.feature.Tick(), fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "polling never continuously corrects manual mode")
        fixture.contexts.value.title := "中文 - refreshed"
        TestAssert.Equal(fixture.feature.Tick().reason, "Unchanged", "same-rule title refresh")
        TestAssert.Equal(fixture.ime.calls.Length, 1, "title refresh respects manual selection")
        fixture.contexts.value.title := "Chinese - another rule"
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 2, "different rule with same action applies")
        fixture.contexts.value.title := "Other"
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls[3][2], "English", "different action applies")
        fixture.contexts.value.title := "Private 中文"
        TestAssert.Equal(fixture.feature.Tick().reason, "Ignored", "Ignore consumes transition without setting")
        TestAssert.Equal(fixture.ime.calls.Length, 3, "Ignore no mode call")
        fixture.contexts.value.processName := "other.exe"
        TestAssert.Equal(fixture.feature.Tick().reason, "NoMatch", "no match consumes transition")
        TestAssert.Equal(fixture.ime.calls.Length, 3, "no match no mode call")
        fixture.contexts.value := {hwnd: 20, processId: 200, processName: "other.exe", title: ""}
        fixture.feature.Tick()
        fixture.contexts.value := {hwnd: 10, processId: 100, processName: "browser.exe", title: "中文"}
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 4, "reentering applies current rule")
        fixture.contexts.value.processId := 101
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 5, "reused HWND in different process is new visit")
        fixture := AutoFixture(), fixture.ime.fail := true
        TestAssert.Equal(fixture.feature.Tick().reason, "VerificationFailed", "mode failure visible")
        fixture.feature.Tick(), fixture.feature.ConfigChanged(), fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "failure not retried for same match or unrelated reload")
        fixture.contexts.value.title := "Other"
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 2, "new rule may retry")
        fixture := AutoFixture(), fixture.ime.throwOnce := true
        TestAssert.Equal(fixture.feature.Tick().reason, "AutoSwitchFailed", "provider exception caught")
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "exception consumed once")
        TestAssert.Equal(fixture.gate.owner, "", "exception releases shared coordinator")
        fixture := AutoFixture(), fixture.enabled := false
        TestAssert.Equal(fixture.feature.Tick().reason, "Paused", "disabled does not observe/apply")
        TestAssert.Equal(fixture.ime.calls.Length, 0, "pause no write")
        fixture.enabled := true, fixture.feature.Reevaluate()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "resume reevaluates once")
        fixture.feature.Reevaluate()
        TestAssert.Equal(fixture.ime.calls.Length, 2, "explicit resume can reapply same rule")
        fixture := AutoFixture(), fixture.gate.TryEnter("Manual")
        TestAssert.Equal(fixture.feature.Tick().reason, "Busy", "manual operation excludes auto")
        TestAssert.Equal(fixture.ime.calls.Length, 0, "busy no write")
        fixture.feature.ObserveManual({changed: true, reason: "CandidatesReady"})
        fixture.gate.Leave("Manual")
        TestAssert.Equal(fixture.feature.Tick().reason, "Unchanged", "resumption consumes refeed's current match")
        fixture.contexts.value.title := "Other"
        TestAssert.Equal(fixture.feature.Tick().reason, "CandidatesProtected", "title cannot overwrite refeed candidates")
        fixture.feature.Reevaluate(), fixture.feature.ConfigChanged(), fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 0, "pause/resume/reload do not break candidate guard")
        fixture.contexts.value.hwnd := 20
        fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "leaving protected visit releases guard")
        TestAssert.Equal(fixture.ime.calls[1][2], "English", "new visit applies current action")
        fixture := AutoFixture()
        fixture.feature.Tick()
        fixture.engine := RuleEngine([fixture.definitions[3], fixture.definitions[2], fixture.definitions[1], fixture.definitions[4]])
        fixture.feature.ConfigChanged(), fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "rule reordering with same match keeps manual choice")
        fixture.definitions[2].mode := "English", fixture.engine := RuleEngine(fixture.definitions)
        fixture.feature.ConfigChanged(), fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 2, "same-ID definition edit applies")
        TestAssert.Equal(fixture.ime.calls[2][2], "English", "new action applied")
        fixture := AutoFixture()
        fixture.engine := RuleEngine([fixture.definitions[4]])
        fixture.feature.Tick(), fixture.contexts.value.title := "any change", fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "process-only rule ignores title refresh")
        fixture := AutoFixture()
        fixture.contexts.value.titleKnown := false
        TestAssert.Equal(fixture.feature.Tick().reason, "NoMatch", "unknown title does not bypass exception")
        fixture.contexts.value.titleKnown := true, fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "known title rematches once")
        fixture := AutoFixture(), fixture.contexts.value.hwnd := 0
        TestAssert.Equal(fixture.feature.Tick().reason, "ContextUnavailable", "missing window has no action")
        TestAssert.Equal(fixture.ime.calls.Length, 0, "missing window no writes")
        fixture := AutoFixture()
        fixture.feature.ObserveManual({changed: false, reason: "NoSelection"}), fixture.feature.Tick()
        TestAssert.Equal(fixture.ime.calls.Length, 1, "empty manual shortcut does not consume pending rule")
        TestAssert.Finish("automatic triggers, manual choice, failures, reload and candidate guard")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
