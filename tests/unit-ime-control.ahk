#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\WindowContext.ahk
#Include ..\src\system\ImeProfiles.ahk
#Include ..\src\system\ImeController.ahk
#Include TestAssert.ahk

class FakeIme extends ImeController {
    __New(openStatus := 1, conversion := 1025) {
        super.__New(10, 60)
        this.openStatus := openStatus, this.conversion := conversion
        this.writes := [], this.tick := 0, this.focused := true
        this.ignoreClose := false, this.failWrite := false, this.loseFocusAfterWrite := false
        this.kind := "SogouPinyin"
        this.languageSupported := true
    }
    Capture(hwnd) => {hwnd: hwnd}
    IsCurrent(*) => this.focused
    Now() => this.tick
    Wait(milliseconds) {
        this.tick += milliseconds
    }
    GetStatus(hwnd) {
        mode := this.languageSupported ? ImeController.DecodeMode(this.openStatus, this.conversion) : "Unsupported"
        return {hwnd: hwnd, imeHwnd: 2, mode: mode, profileKind: this.kind,
            openStatus: this.openStatus, conversionMode: this.conversion,
            reason: mode = "Unknown" ? "ModeFlagsDisagree" : "Observed"}
    }
    Message(hwnd, command, value := 0) {
        this.writes.Push([command, value])
        if this.failWrite
            return {ok: false}
        if command = 2
            this.conversion := value
        if command = 6 && !(this.ignoreClose && !value)
            this.openStatus := value
        if this.loseFocusAfterWrite
            this.focused := false
        return {ok: true}
    }
}

RunTests()
RunTests() {
    try {
        controller := FakeIme()
        result := controller.EnsureEnglish(1)
        TestAssert.Equal(result.ok, true, "English setter readback")
        TestAssert.Equal(controller.writes[1][1], 6, "English uses SETOPENSTATUS")
        TestAssert.Equal(controller.writes[1][2], 0, "English explicitly closes IME")
        TestAssert.Equal(controller.conversion, 1025, "other flags are not clobbered")
        TestAssert.Equal(result.status.openStatus, 0, "English success needs closed IME")
        TestAssert.Equal(controller.EnsureEnglish(1).reason, "AlreadyCorrect", "repeat English is idempotent")
        TestAssert.Equal(controller.writes.Length, 1, "repeat sends no writes")
        controller := FakeIme(1, 1024)
        TestAssert.Equal(controller.GetStatus(1).mode, "Unknown", "reported contradictory state is not English")
        TestAssert.Equal(controller.EnsureEnglish(1).ok, true, "can recover contradictory state by closing")
        controller := FakeIme(1, 1024)
        controller.ignoreClose := true
        TestAssert.Equal(controller.EnsureEnglish(1).ok, false, "ignored close cannot report Verified")
        TestAssert.Equal(controller.GetStatus(1).mode, "Unknown", "failed close stays unknown")
        TestAssert.Equal(controller.writes.Length, 1, "failure does not spam repeated writes")
        controller := FakeIme(0, 0)
        result := controller.EnsureChinese(1)
        TestAssert.Equal(result.ok, true, "Chinese succeeds from closed IME")
        TestAssert.Equal(controller.writes[1][1], 2, "Chinese sets native first")
        TestAssert.Equal(controller.writes[2][1], 6, "Chinese opens after native flag")
        TestAssert.Equal(controller.EnsureChinese(1).reason, "AlreadyCorrect", "repeat Chinese is idempotent")
        controller := FakeIme()
        controller.focused := false
        TestAssert.Equal(controller.EnsureEnglish(1).ok, false, "missing focus rejects write")
        TestAssert.Equal(controller.writes.Length, 0, "no write to unfocused target")
        controller := FakeIme(0, 0)
        controller.loseFocusAfterWrite := true
        TestAssert.Equal(controller.EnsureChinese(1).reason, "FocusChanged", "focus change stops second write")
        TestAssert.Equal(controller.writes.Length, 1, "no open after focus loss")
        controller := FakeIme()
        controller.failWrite := true
        TestAssert.Equal(controller.EnsureEnglish(1).reason, "ImeCloseFailed", "close failure surfaced")
        controller := FakeIme()
        controller.languageSupported := false
        TestAssert.Equal(controller.EnsureEnglish(1).ok, false, "other language left alone")
        TestAssert.Equal(controller.writes.Length, 0, "no other language write")
        TestAssert.Finish("IME explicit open/close, contradictory readback, idempotence and focus failures")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
