#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\WindowContext.ahk
#Include ..\src\system\ImeProfiles.ahk
#Include ..\src\system\ImeController.ahk
#Include TestAssert.ahk

class ReadinessIme extends ImeController {
    __New() {
        super.__New(10, 200)
        this.tick := 0, this.hkl := 0x08040804, this.mode := "Chinese", this.focused := true
        this.hint := "Other", this.writes := 0, this.flipAt := -1, this.recoverAt := -1
    }
    Capture(hwnd) => {hwnd: hwnd, hkl: this.hkl}
    IsCurrent(context) => this.focused && context.hkl = this.hkl
    Now() => this.tick
    Wait(milliseconds) {
        this.tick += milliseconds
        if this.tick = this.flipAt
            this.mode := "English"
        if this.tick = this.recoverAt
            this.mode := "Chinese"
    }
    GetStatus(hwnd) => {mode: (this.hkl & 0xFFFF) = 0x0804 ? this.mode : "Unsupported",
        reason: "Observed", profileKind: this.hint, imeHwnd: 2,
        openStatus: this.mode = "Chinese" ? 1 : 0, conversionMode: 1}
    Message(hwnd, command, value := 0) {
        this.writes += 1
        this.mode := value ? "Chinese" : "English"
        return {ok: true}
    }
}
RunTests()
RunTests() {
    try {
        controller := ReadinessIme(), target := controller.Capture(1)
        TestAssert.Equal(controller.PrepareRefeed(target, "SogouPinyin").ok, true, "stale TSF hint cannot reject target Chinese mode")
        controller.hkl := 0x04110411
        TestAssert.Equal(controller.CheckRefeedContext(controller.Capture(1)).reason, "IgnoredOtherLanguage", "Japanese skip")
        TestAssert.Equal(controller.writes, 0, "Japanese skip requests no activation")
        controller.hkl := 0x04090409
        TestAssert.Equal(controller.CheckRefeedContext(controller.Capture(1)).ok, false, "English keyboard is not Chinese IME internal English mode")
        controller.hkl := 0x08040804
        TestAssert.Equal(controller.PrepareRefeed(controller.Capture(1), "SogouPinyin").ok, true, "return to Chinese works without restart")
        controller.mode := "English"
        TestAssert.Equal(controller.ReadyForInput(controller.Capture(1)).ok, true, "internal English switches to Chinese")
        TestAssert.Equal(controller.writes, 1, "one explicit mode request")
        TestAssert.Equal(controller.tick >= 100, true, "first letter waits for stable readbacks")
        controller := ReadinessIme(), controller.flipAt := 40, controller.recoverAt := 80
        TestAssert.Equal(controller.ReadyForInput(controller.Capture(1)).ok, true, "transient mode acknowledgement settles")
        TestAssert.Equal(controller.tick, 180, "transient flip restarts stable window")
        controller := ReadinessIme(), controller.flipAt := 40
        TestAssert.Equal(controller.ReadyForInput(controller.Capture(1)).reason, "ReadinessFailed", "permanent flip cannot pass readiness")
        TestAssert.Equal(controller.tick, 200, "readiness bounded")
        TestAssert.Equal(controller.writes, 0, "no repeated force-write loop")
        controller := ReadinessIme(), controller.focused := false
        TestAssert.Equal(controller.ReadyForInput(controller.Capture(1)).ok, false, "unfocused readiness fails")
        controller := ReadinessIme(), controller.mode := "English"
        TestAssert.Equal(controller.ReadyForInput(controller.Capture(1), () => false).ok, false, "cancelled operation cannot switch mode")
        TestAssert.Equal(controller.writes, 0, "cancel before request writes nothing")
        controller := ReadinessIme()
        TestAssert.Equal(controller.ReadyForInput(controller.Capture(1), () => controller.tick < 40).ok, false, "pause during settling cancels readiness")
        TestAssert.Equal(controller.tick, 40, "cancel stops settling before first-character readiness")
        TestAssert.Finish("stale profile hints, language return and stable first-character readiness")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
