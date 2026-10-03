#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
#Include ..\src\App.ahk

; Explicit manual opt-in. Run under your normal user, with artificial text only.
if A_Args.Length && A_Args[1] = "--check"
    App().Run(["--check"])
else
    App().Run(["--test-refeed"])
