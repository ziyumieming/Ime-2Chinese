#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\config\Defaults.ahk
#Include ..\src\config\HotkeySpec.ahk
#Include ..\src\config\ConfigStore.ahk
#Include TestAssert.ahk

RunTests()
RunTests() {
    try {
        cfg := ConfigStore.Parse("")
        TestAssert.Equal(cfg.refeedHotkey, "!z", "demo refeed key")
        TestAssert.Equal(cfg.recoverHotkey, "!+z", "demo recover key")
        TestAssert.Equal(cfg.maxRefeedLength, 50, "length before whitespace stripping")
        TestAssert.Equal(cfg.sendIntervalMs, 10, "demo timing")
        TestAssert.Equal(cfg.copyTimeoutMs, 300, "copy timeout")
        TestAssert.Equal(cfg.rules.Length, 0, "no implicit browser rules")
        TestAssert.Equal(cfg.defaultAction, "Ignore", "unmatched stays unchanged")
        example := ConfigStore.Parse(FileRead(A_ScriptDir "\..\config\settings.example.ini", "UTF-8"))
        TestAssert.Equal(example.refeedTarget, "SogouPinyin", "primary IME")
        TestAssert.Equal(HotkeySpec.Parse("+!Z").value, "!+z", "modifier order/case normalized")
        for text in ["[General]`nSendIntervalMs=0", "[General]`nEnableRefeed=2",
            "[General]`nMaxRefeedLength=501", "[General]`nCopyTimeoutMs=1",
            "[General]`nRefeedHotkey=z", "[General]`nRefeedHotkey=!!z",
            "[General]`nRefeedHotkey=!ImaginaryKey", "[General]`nRecoverHotkey=!Z",
            "[General]`nRefeedHotkey=+!z`nRecoverHotkey=!+Z", "[General]`nTypo=1",
            "[General]`nSendIntervalMs=1`nSENDINTERVALMS=2", "[General]`n[general]",
            "[Unknown]`nA=B", "KeyWithoutSection=1", "[Ime]`nRefeedTarget=Other",
            "[AutoSwitch]`nDefaultAction=Chinese", "[Rule.bad]`nProcess=C:\app.exe`nMode=English",
            "[Rule.bad]`nProcess=notepad.exe`nMode=Invalid"]
            TestAssert.Throws(() => ConfigStore.Parse(text), "invalid config rejected")
        rules := ConfigStore.Parse("[Rule.exception]`nProcess=msedge.exe`nTitleContains=中文 = test`nMode=Ignore"
            . "`n[Rule.general]`nProcess=msedge.exe`nMode=Chinese")
        TestAssert.Equal(rules.rules[1].id, "exception", "exception stays first")
        TestAssert.Equal(rules.rules[2].id, "general", "general stays second")
        TestAssert.Equal(rules.rules[1].titleContains, "中文 = test", "unicode and equals retained")
        roundtrip := ConfigStore.Parse(ConfigStore.Serialize(rules))
        TestAssert.Equal(roundtrip.rules[1].titleContains, "中文 = test", "rule roundtrip")
        unsorted := ConfigStore.Parse("[Rule.ZException]`nProcess=msedge.exe`nMode=Ignore"
            . "`n[Rule.AGeneral]`nProcess=msedge.exe`nMode=English")
        TestAssert.Equal(unsorted.rules[1].id, "ZException", "file order is not alphabetical")
        TestAssert.Equal(unsorted.rules[2].id, "AGeneral", "later broad rule stays later")
        savedOrder := ConfigStore.Parse(ConfigStore.Serialize(unsorted))
        TestAssert.Equal(savedOrder.rules[1].id, "ZException", "nonalphabetical order survives serialization")
        TestAssert.Throws(() => ConfigStore.Parse("[Rule.id]`nProcess=a.exe`nMode=Chinese"
            . "`n[Rule.ID]`nProcess=b.exe`nMode=English"), "duplicate IDs differing only in case rejected")

        ; All filesystem mutations are inside this repository's ignored test directory.
        directory := A_ScriptDir "\..\.task-tmp\config-test-" DllCall("GetCurrentProcessId", "UInt")
        path := directory "\settings.ini"
        store := ConfigStore(path)
        try {
            created := store.Load()
            TestAssert.Equal(!!FileExist(path), true, "first launch creates config")
            created.sendIntervalMs := 27
            created.rules := rules.rules
            store.Save(created)
            loaded := store.Load(false)
            TestAssert.Equal(loaded.sendIntervalMs, 27, "changed timing saved")
            TestAssert.Equal(loaded.rules[1].titleContains, "中文 = test", "UTF-8 persistence")
            before := FileRead(path, "UTF-8")
            loaded.sendIntervalMs := -1
            TestAssert.Throws(() => store.Save(loaded), "bad save rejected")
            TestAssert.Equal(FileRead(path, "UTF-8"), before, "bad save leaves outputFile intact")
            outputFile := FileOpen(path, "w", "UTF-8-RAW")
            outputFile.Write("[General]`nSendIntervalMs=oops"), outputFile.Close()
            TestAssert.Throws(() => store.Load(), "bad existing config rejected")
            TestAssert.Equal(FileRead(path, "UTF-8"), "[General]`nSendIntervalMs=oops", "bad outputFile not reset")
        } finally {
            if FileExist(path)
                FileDelete(path)
            if DirExist(directory)
                DirDelete(directory) ; Empty known task directory; never recursive.
        }
        TestAssert.Finish("config defaults, validation, order and safe persistence")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
