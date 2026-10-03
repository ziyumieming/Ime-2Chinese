#Requires AutoHotkey v2.0

class WindowContext {
    static GetActive() => this.Get(DllCall("user32\GetForegroundWindow", "Ptr"))

    static Get(hwnd) {
        context := {hwnd: hwnd, controlHwnd: 0, threadId: 0, inputThreadId: 0, processId: 0,
            processName: "", title: "", className: "", focusKnown: false, hkl: 0}
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return context
        processId := 0
        context.threadId := DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &processId, "UInt")
        context.processId := processId
        info := Buffer(8 + 6 * A_PtrSize + 16, 0)
        NumPut("UInt", info.Size, info)
        if DllCall("user32\GetGUIThreadInfo", "UInt", context.threadId, "Ptr", info, "Int") {
            focus := NumGet(info, 8 + A_PtrSize, "Ptr")
            if focus && DllCall("user32\GetAncestor", "Ptr", focus, "UInt", 2, "Ptr") = hwnd {
                context.controlHwnd := focus
                context.focusKnown := true
            }
        }
        target := context.controlHwnd ? context.controlHwnd : hwnd
        context.inputThreadId := DllCall("user32\GetWindowThreadProcessId", "Ptr", target, "Ptr", 0, "UInt")
        context.hkl := DllCall("user32\GetKeyboardLayout", "UInt", context.inputThreadId, "Ptr")
        try context.processName := WinGetProcessName("ahk_id " hwnd)
        try context.title := WinGetTitle("ahk_id " hwnd)
        try context.className := WinGetClass("ahk_id " hwnd)
        return context
    }

    static IsCurrent(context) {
        current := this.GetActive()
        return context.hwnd && current.hwnd = context.hwnd
            && context.focusKnown && current.focusKnown
            && current.controlHwnd = context.controlHwnd
            && current.inputThreadId = context.inputThreadId
            && current.processId = context.processId
    }
}
