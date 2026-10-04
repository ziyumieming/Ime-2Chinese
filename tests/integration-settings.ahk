#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk

class SettingsUiBindings {
    Apply(*) {
    }
    Clear() {
    }
}
class SettingsUiNotice {
    Show(*) {
    }
}
RunTests()
RunTests() {
    directory := A_ScriptDir "\..\.task-tmp\settings-ui-" DllCall("GetCurrentProcessId", "UInt")
    path := directory "\settings.ini"
    application := App(ConfigStore(path), SettingsUiBindings(), SettingsUiNotice())
    panel := 0, diagnostic := 0
    try {
        application.Start()
        panel := SettingsWindow(application), application.settingsWindow := panel
        panel.window.Show("Hide") ; Size our own window, never activate a desktop target.
        TestAssert.Equal(panel.controls["refeedHotkey"].Value, "Alt+Z", "native edit shows readable hotkey")
        TestAssert.Equal(panel.controls["maxRefeedLength"].Value, "50", "native length default")
        before := FileRead(path, "UTF-8"), panel.controls["sendIntervalMs"].Value := "bad"
        TestAssert.Equal(panel.Save().ok, false, "invalid native form rejected")
        TestAssert.Equal(FileRead(path, "UTF-8"), before, "bad form leaves file intact")
        TestAssert.Equal(panel.controls["sendIntervalMs"].Value, "bad", "bad draft retained for correction")
        panel.controls["sendIntervalMs"].Value := "31"
        panel.controls["refeedHotkey"].Value := "Ctrl+Alt+F8"
        pending := application.store.Load(false), pending.maxRefeedLength := 80
        pending.rules := [{id: "Later", process: "notepad.exe", titleContains: "", mode: "Ignore"}]
        application.store.Save(pending)
        TestAssert.Equal(panel.Save().ok, true, "native form saves")
        TestAssert.Equal(application.store.Load(false).sendIntervalMs, 31, "UTF-8 file saved")
        TestAssert.Equal(application.settings.maxRefeedLength, 80, "pending field preserved")
        TestAssert.Equal(application.settings.rules[1].id, "Later", "pending rule preserved")
        TestAssert.Equal(panel.controls["maxRefeedLength"].Value, "80", "merged file shown in form")
        panel.controls["sendIntervalMs"].Value := "40"
        pending := application.store.Load(false), pending.sendIntervalMs := 45, application.store.Save(pending)
        TestAssert.Equal(panel.Save().ok, false, "conflicting field rejected through form")
        TestAssert.Equal(panel.controls["sendIntervalMs"].Value, "40", "conflicting draft retained")
        panel.Hide(), panel.Show(), panel.window.Hide()
        TestAssert.Equal(panel.controls["sendIntervalMs"].Value, "45", "reopening settings replaces draft")
        TestAssert.Equal(panel.controls["sendIntervalMs"].Value, "45", "current file reloaded")
        TestAssert.Equal(application.settings.sendIntervalMs, 31, "read alone does not apply")
        TestAssert.Equal(panel.Save().ok, true, "unchanged reloaded form applies file")
        TestAssert.Equal(application.settings.sendIntervalMs, 45, "read file preferences applied")
        panel.window.GetClientPos(, , &clientWidth, &clientHeight)
        panel.saveButton.GetPos(&x, &y, &width, &height)
        TestAssert.Equal(x + width <= clientWidth && y + height <= clientHeight, true, "settings buttons inside client")
        diagnostic := DiagnosticsWindow(application), application.diagnosticsWindow := diagnostic
        diagnostic.window.Show("Hide")
        TestAssert.Equal(InStr(diagnostic.text.Value, "设置保存：已保存") > 0, true, "native diagnostic shows readable save")
        diagnostic.Clear()
        TestAssert.Equal(application.logger.entries.Length, 0, "clear removes only in-memory history")
        TestAssert.Equal(InStr(diagnostic.text.Value, "暂无诊断。") > 0, true, "empty state refreshed")
        diagnostic.Resize(0, 500, 300)
        diagnostic.clearButton.GetPos(, &y, , &height)
        TestAssert.Equal(y + height <= 300, true, "diagnostic actions fit minimum resize")
        firstHwnd := panel.window.Hwnd, secondHwnd := diagnostic.window.Hwnd
        application.Stop(), application.Stop()
        TestAssert.Equal(DllCall("IsWindow", "Ptr", firstHwnd), 0, "settings window destroyed on stop")
        TestAssert.Equal(DllCall("IsWindow", "Ptr", secondHwnd), 0, "diagnostics window destroyed on stop")
        TestAssert.Finish("hidden native settings, config persistence, diagnostics and cleanup")
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    } finally {
        application.Stop()
        if FileExist(path)
            FileDelete(path)
        if DirExist(directory)
            DirDelete(directory) ; This private test directory contains no other files.
    }
    ExitApp(0)
}
