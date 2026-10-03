#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\WindowContext.ahk
#Include TestAssert.ahk

RunTests()
RunTests() {
    try {
        missing := WindowContext.Get(0)
        TestAssert.Equal(missing.hwnd, 0, "no invented window")
        TestAssert.Equal(missing.processKnown, false, "invalid process unknown")
        TestAssert.Equal(missing.titleKnown, false, "invalid title unknown")
        TestAssert.Equal(missing.focusKnown, false, "invalid focus unknown")
        TestAssert.Equal(missing.inputThreadId, 0, "invalid context has no target thread")
        TestAssert.Equal(WindowContext.IsCurrent(missing), false, "invalid context never current")
        ; Hidden owned windows only: no activation, text injection or IME writes.
        previousHidden := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        window := Gui(, ""), handle := window.Hwnd
        try {
            window.Show("Hide")
            observed := WindowContext.Get(handle)
            TestAssert.Equal(observed.hwnd, handle, "reads explicit owned handle")
            TestAssert.Equal(observed.processId, DllCall("GetCurrentProcessId", "UInt"), "owned process identity")
            TestAssert.Equal(observed.processKnown, true, "process read is known")
            SplitPath(A_AhkPath, &executableName)
            TestAssert.Equal(observed.processName, executableName, "native process filename")
            TestAssert.Equal(observed.titleKnown, true, "empty title is known")
            TestAssert.Equal(observed.title, "", "empty title preserved")
            TestAssert.Equal(observed.className, "AutoHotkeyGUI", "native window class")
            TestAssert.Equal(observed.threadId > 0, true, "native target thread")
            window.Title := "规则 中文 = title"
            TestAssert.Equal(WindowContext.Get(handle).title, "规则 中文 = title", "Unicode title preserved")
            window.Destroy()
            stale := WindowContext.Get(handle)
            TestAssert.Equal(stale.processKnown, false, "destroyed handle process unknown")
            TestAssert.Equal(stale.titleKnown, false, "destroyed handle title unknown")
            TestAssert.Equal(stale.focusKnown, false, "destroyed handle focus unknown")
        } finally {
            window.Destroy()
            DetectHiddenWindows(previousHidden)
        }
        TestAssert.Finish("invalid, hidden owned and destroyed window context")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
