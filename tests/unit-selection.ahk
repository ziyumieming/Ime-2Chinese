#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\SelectionProbe.ahk
#Include TestAssert.ahk

class ProbeDriver {
    __New() => this.state := "Empty"
    Read(*) {
        if this.state = "throw"
            throw Error("provider unavailable")
        return {state: this.state, token: 0}
    }
    IsCurrent(*) => false
}
RunTests()
RunTests() {
    try {
        driver := ProbeDriver(), probe := SelectionProbe(driver)
        TestAssert.Equal(probe.Check({}).state, "Empty", "empty selection distinct")
        driver.state := "Selected"
        TestAssert.Equal(probe.Check({}).state, "Selected", "selection observed")
        driver.state := "throw"
        TestAssert.Equal(probe.Check({}).state, "Unknown", "provider error does not guess empty")
        TestAssert.Equal(probe.IsCurrent({token: 0}), true, "native HWND token needs no UIA query")
        TestAssert.Equal(probe.IsCurrent({token: {}}), false, "different UIA field fails target check")
        native := NativeSelection()
        TestAssert.Equal(native.Read({focusKnown: false}).state, "Unknown", "unknown focus does not query/copy")
        window := Gui(), editor := window.AddEdit(, "nihao")
        try {
            DllCall("user32\SendMessageW", "Ptr", editor.Hwnd, "UInt", 0xB1, "Ptr", 0, "Ptr", 0)
            TestAssert.Equal(native.ReadEdit(editor.Hwnd).state, "Empty", "owned Edit caret is empty")
            DllCall("user32\SendMessageW", "Ptr", editor.Hwnd, "UInt", 0xB1, "Ptr", 0, "Ptr", 5)
            TestAssert.Equal(native.ReadEdit(editor.Hwnd).state, "Selected", "owned Edit selection without copying")
            connection := 0, transaction := 0
            ComCall(60, native.Factory(), "UInt*", &connection)
            ComCall(62, native.Factory(), "UInt*", &transaction)
            TestAssert.Equal(connection, 200, "UIA connection timeout configured")
            TestAssert.Equal(transaction, 200, "UIA transaction timeout configured")
            element := 0
            ComCall(6, native.Factory(), "Ptr", editor.Hwnd, "Ptr*", &element)
            snapshot := native.ReadElement(element, DllCall("GetCurrentProcessId", "UInt"))
            TestAssert.Equal(snapshot.state, "Selected", "owned Edit UIA range has distinct endpoints")
        } finally {
            window.Destroy()
        }
        TestAssert.Finish("selection without copying, focus tokens, owned Edit and UIA timeouts")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
