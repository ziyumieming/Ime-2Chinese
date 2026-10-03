#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include FakeInput.ahk
#Include TestAssert.ahk

class AutoStore {
    __New() {
        this.value := Defaults.Create(), this.failSave := false
        this.value.rules := [{id: "Notes", process: "notepad.exe", titleContains: "", mode: "English"}]
    }
    Load(*) => ConfigStore.Parse(ConfigStore.Serialize(this.value))
    Save(settings) {
        if this.failSave
            throw Error("disk failure")
        this.value := ConfigStore.Parse(ConfigStore.Serialize(settings))
    }
}
class AutoBindings {
    Apply(*) {
    }
    Clear() {
    }
}
class AutoNotice {
    __New() => this.count := 0
    Show(*) => this.count += 1
}
class FakeScheduler {
    __New() {
        this.interval := 0, this.callback := 0, this.failNext := false
    }
    Start(callback, interval) {
        if this.failNext {
            this.failNext := false
            throw Error("timer failed")
        }
        this.callback := callback, this.interval := interval
    }
    Stop(*) => this.interval := 0
    Fire() {
        if this.interval
            return this.callback.Call()
    }
}
class AppAutoContext extends FakeContext {
    Capture() => {hwnd: this.identity, processId: 123, processName: "notepad.exe", title: "Private title", identity: this.identity}
}
class AppAutoIme extends PreparedIme {
    __New() {
        super.__New()
        this.modes := [], this.onMode := (*) => 0
    }
    EnsureMode(hwnd, mode, *) {
        this.modes.Push(mode), this.onMode.Call()
        return {ok: true, reason: "Verified"}
    }
}
RunTests()
RunTests() {
    try {
        store := AutoStore(), timer := FakeScheduler(), notice := AutoNotice()
        contexts := AppAutoContext(), controller := AppAutoIme()
        application := App(store, AutoBindings(), notice)
        application.AttachAuto({contexts: contexts, ime: controller}, timer)
        TestAssert.Equal(application.Start(), true, "auto test app starts")
        TestAssert.Equal(timer.interval, 300, "configured polling interval")
        TestAssert.Equal(controller.modes.Length, 1, "startup applies once")
        timer.Fire(), timer.Fire()
        TestAssert.Equal(controller.modes.Length, 1, "timer does not force manual mode")
        TestAssert.Equal(application.TogglePause(), true, "pause succeeds")
        TestAssert.Equal(timer.interval, 0, "pause stops timer")
        application.TogglePause()
        TestAssert.Equal(controller.modes.Length, 2, "resume applies once")
        store.value.pollIntervalMs := 800
        TestAssert.Equal(application.Reload(), true, "poll interval reload")
        TestAssert.Equal(timer.interval, 800, "new interval effective")
        timer.Fire()
        TestAssert.Equal(controller.modes.Length, 2, "unrelated reload preserves manual choice")
        store.value.rules[1].mode := "Chinese", timer.failNext := true
        TestAssert.Equal(application.Reload(), false, "timer failure rejects candidate")
        TestAssert.Equal(application.settings.rules[1].mode, "English", "timer failure keeps settings")
        TestAssert.Equal(application.rules.Match(contexts.Capture()).mode, "English", "timer failure keeps rule engine")
        TestAssert.Equal(timer.interval, 800, "timer failure restores prior interval")
        TestAssert.Equal(application.Reload(), true, "valid timer retry")
        timer.Fire()
        TestAssert.Equal(controller.modes[3], "Chinese", "changed rule applied once")
        store.failSave := true
        TestAssert.Equal(application.ToggleFeature("enableAutoSwitch"), false, "save failure rejects disable")
        TestAssert.Equal(application.settings.enableAutoSwitch, true, "save failure keeps enabled preference")
        TestAssert.Equal(timer.interval, 800, "save failure restores timer")
        store.failSave := false
        application.ToggleFeature("enableAutoSwitch")
        TestAssert.Equal(timer.interval, 0, "disable stops polling")
        application.ToggleFeature("enableAutoSwitch")
        TestAssert.Equal(controller.modes.Length, 4, "reenable reevaluates once")
        store.value.enableAutoSwitch := false, application.Reload()
        TestAssert.Equal(timer.interval, 0, "file reload disable stops polling")
        store.value.enableAutoSwitch := true, application.Reload(), timer.Fire()
        TestAssert.Equal(controller.modes.Length, 5, "file reload enable reevaluates once")

        output := FakeOutput(), clipDriver := FakeClipboardDriver()
        application.AttachRefeed({contexts: contexts, keys: FakeKeys(), ime: controller,
            clipboard: ClipboardService(clipDriver), sender: TextSender(output), selection: FakeSelection()})
        callbackOwner := ""
        controller.onPrepare := (*) => ObserveBusy(application, timer, &callbackOwner)
        TestAssert.Equal(application.RunInputAction(false).ok, true, "coordinated refeed succeeds")
        TestAssert.Equal(callbackOwner, "Manual", "refeed owns gate during mode preparation")
        TestAssert.Equal(controller.modes.Length, 5, "timer callback cannot compete during refeed")
        TestAssert.Equal(application.gate.owner, "", "manual completion releases shared gate")
        timer.Fire()
        TestAssert.Equal(controller.modes.Length, 5, "polling resumes without overriding candidates")
        application.TogglePause(), application.TogglePause()
        TestAssert.Equal(controller.modes.Length, 5, "candidate guard survives pause/resume")
        contexts.identity := 2, timer.Fire()
        TestAssert.Equal(controller.modes.Length, 6, "new window releases candidate guard")
        controller.onMode := (*) => TestAssert.Equal(application.refeed.ConvertSelection().reason, "Busy", "auto owns gate before manual can start")
        contexts.identity := 3, timer.Fire()
        TestAssert.Equal(application.gate.owner, "", "auto completion releases gate")
        TestAssert.Equal(clipDriver.copies, 2, "busy manual attempt sends no additional copy")
        TestAssert.Equal(InStr(application.logger.Recent(), "Private title"), 0, "auto diagnostic excludes title")
        application.Stop(), application.Stop()
        TestAssert.Equal(timer.interval, 0, "exit cancels polling idempotently")

        ; Native scheduler only: no foreground window queries or IME operations.
        scheduler := PollScheduler(), ticks := 0, callback := (*) => ticks += 1
        try {
            scheduler.Start(callback, 20)
            deadline := A_TickCount + 500
            while !ticks && A_TickCount < deadline
                Sleep(10)
            TestAssert.Equal(ticks > 0, true, "native timer runs")
            scheduler.Stop(callback), before := ticks
            Sleep(50)
            TestAssert.Equal(ticks, before, "native timer cancellation")
        } finally {
            scheduler.Stop(callback)
        }
        TestAssert.Finish("auto lifecycle, timer rollback, shared coordinator and native timer cleanup")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
ObserveBusy(application, timer, &owner) {
    owner := application.gate.owner
    TestAssert.Equal(timer.Fire().reason, "Busy", "timer busy during manual input")
}
