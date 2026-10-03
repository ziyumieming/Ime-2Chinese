#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
#Include ..\src\system\WindowContext.ahk
#Include ..\src\system\ImeProfiles.ahk
#Include ..\src\system\ImeController.ahk

FileEncoding("UTF-8")
if A_Args.Length && A_Args[1] = "--check" {
    FileAppend("IME smoke tool loaded; no hotkeys or desktop operations started.`n", "*")
    ExitApp(0)
}

; Run manually under the interactive user, then focus an empty test editor.
; No text is copied, deleted or sent. Profile activation is deliberately absent.
Hotkey("^!F8", (*) => Smoke("Read"))
Hotkey("^!F9", (*) => Smoke("Chinese"))
Hotkey("^!F10", (*) => Smoke("English"))
Persistent()

Smoke(action) {
    static busy := false
    if busy
        return
    busy := true
    try {
        context := WindowContext.GetActive()
        if !KeyWait("Control", "T2") || !KeyWait("Alt", "T2") {
            Report(action, "HotkeyReleaseTimeout")
            return
        }
        if !WindowContext.IsCurrent(context) {
            Report(action, "TargetNotFocusedOrFocusUnknown")
            return
        }
        controller := ImeController()
        if action = "Read" {
            status := controller.GetStatus(context.hwnd)
            outcome := status.reason
        } else {
            result := controller.EnsureMode(context.hwnd, action)
            outcome := result.reason
            status := result.HasOwnProp("status") ? result.status : controller.GetStatus(context.hwnd)
        }
        summary := Format("{} | mode={} | profileHint={} | open={} | conversion={} | focusKnown={}",
            outcome, status.mode, status.profileKind, status.openStatus,
            status.conversionMode, context.focusKnown)
        Report(action, summary)
    } catch as err {
        Report(action, "Error: " err.Message)
    } finally {
        busy := false
    }
}

Report(action, summary) {
    text := action ": " summary
    ToolTip(text)
    SetTimer(() => ToolTip(), -5000)
    ; Local-only diagnostic fields: no title, selected text, clipboard or document.
    try {
        DirCreate(A_ScriptDir "\..\logs")
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " text "`n",
            A_ScriptDir "\..\logs\ime-smoke.log", "UTF-8")
    }
}
