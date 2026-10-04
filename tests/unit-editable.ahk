#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\config\Defaults.ahk
#Include ..\src\common\TextRules.ahk
#Include ..\src\system\ClipboardService.ahk
#Include ..\src\system\TextSender.ahk
#Include ..\src\features\RefeedFeature.ahk
#Include FakeInput.ahk
#Include TestAssert.ahk

RunTests()
RunTests() {
try {
    native := NativeEditable(), window := Gui()
    normal := window.AddEdit(, "test"), readonly := window.AddEdit("ReadOnly", "test")
    password := window.AddEdit("Password", "secret"), disabled := window.AddEdit("Disabled", "test")
    TestAssert.Equal(native.ReadNative(normal.Hwnd).state, "Editable", "native writable edit")
    TestAssert.Equal(native.ReadNative(readonly.Hwnd).reason, "ReadOnlyTarget", "native readonly edit")
    TestAssert.Equal(native.ReadNative(password.Hwnd).reason, "PasswordTarget", "native password edit")
    TestAssert.Equal(native.ReadNative(disabled.Hwnd).reason, "TargetDisabled", "native disabled edit")
    TestAssert.Equal(native.Decide(1, 0, "Unknown", 50004).state, "Blocked", "unknown provider fails closed")
    TestAssert.Equal(native.Decide(1, 0, 0, 50033).state, "Blocked", "writable metadata alone does not admit pane")
    TestAssert.Equal(native.Decide(1, 0, 0, 50030).state, "Editable", "writable document supports contenteditable")
    TestAssert.Equal(native.Read({focusKnown: true, className: "ConsoleWindowClass"}).reason, "TerminalUnsupported", "console explicit exclusion")
    ; Exercise actual COM vtable metadata on our own hidden GUI, without focus.
    element := 0
    ComCall(6, native.Factory(), "Ptr", normal.Hwnd, "Ptr*", &element)
    TestAssert.Equal(native.ReadElement(element, DllCall("GetCurrentProcessId", "UInt")).state, "Editable", "native UIA ValuePattern readonly metadata")
    window.Destroy()
    for reason in ["ReadOnlyTarget", "PasswordTarget", "TargetDisabled", "EditableUnknown", "NonEditableTarget", "TerminalUnsupported"] {
        driver := FakeClipboardDriver(), output := FakeOutput(), editable := FakeEditable()
        editable.state := "Blocked", editable.reason := reason
        feature := RefeedFeature(() => Defaults.Create(), {contexts: FakeContext(), keys: FakeKeys(),
            clipboard: ClipboardService(driver), sender: TextSender(output), ime: PreparedIme(),
            selection: FakeSelection(), editable: editable}, () => true)
        feature.lastOriginal := "saved"
        TestAssert.Equal(feature.ConvertSelection().reason, reason, "blocked refeed reason")
        TestAssert.Equal(feature.RecoverLast().reason, reason, "recovery also needs writable target")
        TestAssert.Equal(driver.sequenceNumber, 10, "blocked target does not touch clipboard")
        TestAssert.Equal(output.deletes + output.literal.Length, 0, "blocked target does not send")
        TestAssert.Equal(feature.lastOriginal, "saved", "blocked target preserves recovery cache")
    }
    editable.state := "Editable", editable.current := true
    output.onLetter := (*) => editable.current := false
    result := feature.ConvertSelection()
    TestAssert.Equal(result.reason, "SendingStopped", "UIA element change stops sending")
    TestAssert.Equal(result.sent, 1, "only first character sent before element change")
    TestAssert.Finish("editable targets, real native UIA metadata and safe refeed/recovery guards")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
    ExitApp(1)
}
}
