#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\WindowContext.ahk
#Include ..\src\system\ImeProfiles.ahk
#Include ..\src\system\ImeController.ahk

cases := [[0, 0, "English"], [0, 1, "English"], [1, 0, "English"], [1, 1, "Chinese"],
    [1, 9, "Chinese"], [1, 8, "English"], [-1, 1, "Unknown"], [2, 1, "Unknown"],
    [1, -1, "Unknown"], [1, 0xFFFFFFFF, "Unknown"]]
for index, sample in cases {
    actual := ImeController.DecodeMode(sample[1], sample[2])
    if actual != sample[3] {
        FileAppend("FAIL case " index ": " actual "`n", "*")
        ExitApp(1)
    }
}
FileAppend("PASS " cases.Length " IME status cases; OpenStatus alone is not Chinese proof.`n", "*")
ExitApp(0)
