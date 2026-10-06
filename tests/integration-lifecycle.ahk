#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk

class SilentNotify {
    Show(*) {
    }
}

RunTests()
RunTests() {
    directory := A_ScriptDir "\..\.task-tmp\lifecycle-test-" DllCall("GetCurrentProcessId", "UInt")
    path := directory "\settings.ini"
    application := App(ConfigStore(path), HotkeyBindings(), SilentNotify())
    try {
        settings := Defaults.Create()
        settings.refeedHotkey := "^!#F23", settings.recoverHotkey := "^!#F24"
        application.store.Save(settings)
        application.Run([]) ; Production path, rare shortcuts; no callback invoked.
        TestAssert.Equal(application.ready, true, "normal entry stays resident")
        TestAssert.Equal(application.HasOwnProp("tray"), true, "tray created")
        TestAssert.Equal(DllCall("GetMenuItemCount", "Ptr", A_TrayMenu.Handle, "Int") > 0, true, "native menu populated")
        TestAssert.Equal(application.hotkeys.active.Length, 2, "production manual shortcuts registered")
        TestAssert.Equal(application.HasOwnProp("auto"), false, "frozen automatic switching not attached")
        TestAssert.Equal(application.testMode, false, "normal entry is not legacy MVP")
        application.TogglePause()
        TestAssert.Equal(application.paused, true, "pause via native lifecycle")
        application.TogglePause()
        TestAssert.Equal(application.paused, false, "resume via native lifecycle")
        TestAssert.Equal(application.Reload(), true, "reload generated config")
        ; Register then disable a rare shortcut; no key is sent or callback invoked.
        application.hotkeys.Apply([{key: "^!#F23", callback: (*) => 0}])
        TestAssert.Equal(application.hotkeys.active.Length, 1, "native registration accepted")
        application.Stop()
        TestAssert.Equal(application.hotkeys.active.Length, 0, "native cleanup completed")
        TestAssert.Equal(application.ready, false, "stopped state recorded")
        OnExit(application.exitHandler, 0)
        TestAssert.Finish("native tray startup, reload and hotkey registration cleanup; no IME writes")
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        application.Stop()
        ExitApp(1)
    } finally {
        if FileExist(path)
            FileDelete(path)
        if DirExist(directory)
            DirDelete(directory)
    }
    ExitApp(0)
}
