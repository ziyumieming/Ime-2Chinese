#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk
class CaptureStore {
    __New() => (this.settings := Defaults.Create(), this.failSave := false)
    Load(*) => SettingsModel.Clone(this.settings)
    Save(value) {
        if this.failSave
            throw Error("disk failure")
        this.settings := SettingsModel.Clone(value)
    }
}
class CaptureBindings {
    __New() => this.count := 0
    Apply(keys) => this.count := keys.Length
    Clear() => this.count := 0
}
class CaptureNotice {
    Show(*) {
    }
}
RunTests()
RunTests() {
    directory := A_ScriptDir "\..\.task-tmp\startup-recording-" DllCall("GetCurrentProcessId", "UInt")
    startup := StartupService(directory), store := CaptureStore(), bindings := CaptureBindings()
    application := App(store, bindings, CaptureNotice(), startup)
    recorder := 0, panel := 0
    try {
        application.handlers["refeed"] := (*) => 0
        application.handlers["recover"] := (*) => 0
        TestAssert.Equal(application.Start(), true, "private application starts")
        TestAssert.Equal(FileExist(startup.path), "", "default does not create startup entry")
        baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline)
        values.startWithWindows := 1, store.failSave := true
        TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "disk failure rejects startup setting")
        TestAssert.Equal(FileExist(startup.path), "", "disk failure rolls back created shortcut")
        TestAssert.Equal(application.settings.startWithWindows, false, "failed preference not applied")
        TestAssert.Equal(bindings.count, 2, "failed startup transaction restores hotkeys")
        store.failSave := false
        TestAssert.Equal(application.SaveSettings(baseline, values).ok, true, "startup enabled with real private shortcut")
        FileGetShortcut(startup.path, &target, , &arguments, &description)
        TestAssert.Equal(target, A_AhkPath, "source startup targets installed AHK")
        TestAssert.Equal(InStr(arguments, '"' startup.entry '"') > 0, true, "absolute source path quoted")
        TestAssert.Equal(description, startup.marker, "shortcut ownership marked")
        saved := FileRead(startup.path, "RAW")
        baseline := SettingsModel.Clone(application.settings), values := SettingsModel.Values(baseline)
        values.startWithWindows := 0, store.failSave := true
        TestAssert.Equal(application.SaveSettings(baseline, values).ok, false, "disable failure rejected")
        TestAssert.Equal(FileRead(startup.path, "RAW").Size, saved.Size, "disable rollback restores original shortcut")
        TestAssert.Equal(application.settings.startWithWindows, true, "failed disable remains enabled")
        store.failSave := false
        TestAssert.Equal(application.SaveSettings(baseline, values).ok, true, "startup disabled")
        TestAssert.Equal(FileExist(startup.path), "", "managed shortcut removed")
        FileCreateShortcut(A_AhkPath, startup.path, , , "unrelated")
        TestAssert.Throws(() => startup.Snapshot(), "foreign shortcut never overwritten")
        FileDelete(startup.path)
        TestAssert.Equal(HotkeyRecorder.Build("Z", "!+"), "!+z", "recording normalization")
        TestAssert.Throws(() => HotkeyRecorder.Build("Z", ""), "plain key rejected")
        keys := Map()
        keys.CaseSense := "Off"
        for pair in [["Ctrl", 0], ["Alt", 1], ["Shift", 0], ["LWin", 0], ["RWin", 0], ["z", 1]]
            keys[pair[1]] := pair[2]
        candidate := "", completed := "", cancelled := 0, foreground := 123
        recorder := HotkeyRecorder(123, (value, *) => candidate := value, (value) => completed := value,
            () => cancelled += 1, (key) => keys.Has(key) ? keys[key] : 0, () => foreground)
        recorder.Start()
        TestAssert.Equal(recorder.hook.InProgress, true, "native InputHook starts without collecting text")
        recorder.KeyDown(recorder.hook, 0x5A, 0x2C)
        TestAssert.Equal(candidate, "!z", "key event records Alt+Z")
        recorder.KeyUp()
        TestAssert.Equal(completed, "", "held key cannot reactivate business shortcut")
        keys["z"] := 0, keys["Alt"] := 0, recorder.KeyUp()
        TestAssert.Equal(completed, "!z", "completion waits for all key releases")
        TestAssert.Equal(recorder.hook.InProgress, false, "hook stopped after recording")
        recorder.Start(), recorder.KeyDown(recorder.hook, 0x1B, 1)
        TestAssert.Equal(cancelled, 1, "Esc cancels")
        recorder.Start(), foreground := 456, recorder.KeyDown(recorder.hook, 0x5A, 0x2C)
        TestAssert.Equal(cancelled, 2, "focus loss cancels without collecting another app's key")
        panel := SettingsWindow(application), panel.window.Show("Hide")
        TestAssert.Equal(WinGetStyle("ahk_id " panel.controls["refeedHotkey"].Hwnd) & 0x800 > 0, true, "hotkey field readonly")
        panel.RecordKey("refeedHotkey")
        TestAssert.Equal(bindings.count, 0, "business keys unregistered during native UI recording")
        TestAssert.Equal(application.BeginHotkeyCapture(), false, "nested recording rejected")
        panel.Hide()
        TestAssert.Equal(bindings.count, 2, "hide/cancel restores business shortcuts")
        TestAssert.Equal(application.recordingHotkey, false, "capture state released")
        panel.Close(), panel := 0
        TestAssert.Finish("startup shortcut transactions, hotkey event recording, cancellation and cleanup")
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    } finally {
        if recorder
            recorder.Stop()
        if panel
            panel.Close()
        application.Stop()
        if FileExist(startup.path)
            FileDelete(startup.path)
        if DirExist(directory)
            DirDelete(directory)
    }
    ExitApp(0)
}
