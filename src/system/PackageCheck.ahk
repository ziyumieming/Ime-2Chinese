#Requires AutoHotkey v2.0

; Bounded package verification. Never uses real preferences or the Startup folder,
; sends keys, accesses selected text or writes IME state.
class PackageCheck {
    static Run() {
        directory := A_Temp "\Ime-2Chinese-check-" DllCall("GetCurrentProcessId", "UInt")
        if DirExist(directory)
            throw Error("Private check directory already exists")
        DirCreate(directory)
        application := App(ConfigStore(directory "\settings.ini"), HotkeyBindings(), PackageCheckNotify(), StartupService(directory))
        try {
            settings := Defaults.Create()
            settings.refeedHotkey := "^!#F23", settings.recoverHotkey := "^!#F24"
            settings.startWithWindows := false
            application.store.Save(settings)
            application.Run([])
            if !application.ready || !application.HasOwnProp("tray") || !application.HasOwnProp("refeed")
                throw Error("Production entry did not initialize")
            if application.testMode || application.HasOwnProp("auto") || application.hotkeys.active.Length != 2
                throw Error("Production feature scope mismatch")
            application.TogglePause()
            if application.hotkeys.active.Length != 0
                throw Error("Pause did not release shortcuts")
            application.TogglePause()
            if application.hotkeys.active.Length != 2
                throw Error("Resume did not restore shortcuts")
            application.startup.Apply(true)
            FileGetShortcut(application.startup.path, &target, , &arguments)
            if A_IsCompiled && (target != A_ScriptFullPath || arguments != "")
                throw Error("Compiled startup points outside standalone EXE")
            application.startup.Apply(false)
            application.Stop()
            if application.ready || application.hotkeys.active.Length != 0
                throw Error("Lifecycle cleanup failed")
            FileAppend("PASS package lifecycle; version=" AppInfo.Version "; compiled=" A_IsCompiled "; manual=1; auto=0`n", "*")
        } catch as err {
            FileAppend("FAIL package lifecycle: " err.Message " (line " err.Line ")`n", "*")
            ExitApp(1)
        } finally {
            application.Stop()
            OnExit(application.exitHandler, 0)
            ; The fixed, process-specific directory was created exclusively above.
            DirDelete(directory, true)
        }
        ExitApp(0)
    }
}

class PackageCheckNotify {
    Show(*) {
    }
}
