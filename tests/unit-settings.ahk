#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\config\SettingsModel.ahk
#Include TestAssert.ahk

RunTests()
RunTests() {
try {
    baseline := Defaults.Create(), values := SettingsModel.Values(baseline)
    TestAssert.Equal(values.refeedHotkey, "Alt+Z", "readable default hotkey")
    TestAssert.Equal(values.recoverHotkey, "Alt+Shift+Z", "readable recovery hotkey")
    TestAssert.Equal(SettingsModel.ReadHotkey(" shift + CTRL + Alt + F8 "), "^!+f8", "human modifiers normalized")
    TestAssert.Equal(SettingsModel.ReadHotkey("^!#x"), "^!#x", "INI syntax remains accepted")
    TestAssert.Equal(SettingsModel.DisplayHotkey("#!^f8"), "Ctrl+Alt+Win+F8", "Win supported in readable form")
    TestAssert.Throws(() => SettingsModel.ReadHotkey("Z"), "modifier required")
    TestAssert.Throws(() => SettingsModel.ReadHotkey("Alt+Alt+Z"), "duplicate modifier rejected")
    TestAssert.Throws(() => SettingsModel.ReadHotkey("Meta+Z"), "unknown modifier rejected")
    TestAssert.Throws(() => SettingsModel.ReadHotkey("Alt+"), "missing key rejected")
    TestAssert.Throws(() => SettingsModel.ReadHotkey("Alt+unknownkey"), "unknown key rejected")
    values.refeedHotkey := "Alt+Shift+Z"
    TestAssert.Throws(() => SettingsModel.Normalize(values), "same hotkey conflict")
    values := SettingsModel.Values(baseline)
    for row in [["sendIntervalMs", "0"], ["maxRefeedLength", "501"], ["copyTimeoutMs", "49"],
        ["pollIntervalMs", "5001"], ["sendIntervalMs", "1.5"], ["maxRefeedLength", "abc"]] {
        values.%row[1]% := row[2]
        TestAssert.Throws(() => SettingsModel.Normalize(values), "invalid numeric preference")
        values := SettingsModel.Values(baseline)
    }
    values.enableAutoSwitch := 2
    TestAssert.Throws(() => SettingsModel.Normalize(values), "invalid boolean")
    values := SettingsModel.Values(baseline), values.sendIntervalMs := "0017"
    latest := SettingsModel.Clone(baseline), latest.maxRefeedLength := 70
    latest.refeedTarget := "MicrosoftPinyin"
    latest.rules := [{id: "Keep", process: "notepad.exe", titleContains: "private title", mode: "Ignore"}]
    merged := SettingsModel.Merge(baseline, values, latest)
    TestAssert.Equal(merged.settings.sendIntervalMs, 17, "changed field patched")
    TestAssert.Equal(merged.settings.maxRefeedLength, 70, "unrelated file edit kept")
    TestAssert.Equal(merged.settings.rules[1].id, "Keep", "pending rule kept")
    TestAssert.Equal(merged.settings.refeedTarget, "MicrosoftPinyin", "legacy target kept without UI selector")
    TestAssert.Equal(merged.changes, 1, "one field changed")
    TestAssert.Equal(baseline.sendIntervalMs, 10, "baseline not mutated")
    TestAssert.Equal(latest.sendIntervalMs, 10, "file snapshot not mutated")
    latest.sendIntervalMs := 18
    TestAssert.Throws(() => SettingsModel.Merge(baseline, values, latest), "same field conflicting file change rejected")
    latest.sendIntervalMs := 17
    TestAssert.Equal(SettingsModel.Merge(baseline, values, latest).settings.sendIntervalMs, 17, "same desired file edit accepted")
    values := SettingsModel.Values(baseline), latest.sendIntervalMs := 18
    TestAssert.Equal(SettingsModel.Merge(baseline, values, latest).settings.sendIntervalMs, 18, "unmodified field follows file")
    values.refeedHotkey := "Ctrl+X", latest.recoverHotkey := "^x"
    TestAssert.Throws(() => SettingsModel.Merge(baseline, values, latest), "cross-field collision with latest config rejected")
    TestAssert.Finish("readable settings, validation, pending edits and field conflicts")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
    ExitApp(1)
}
}
