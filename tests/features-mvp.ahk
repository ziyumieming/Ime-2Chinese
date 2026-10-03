#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
#Include ..\src\App.ahk

; Explicit opt-in only. Rules are supplied by the user, never browser-wide defaults.
App().Run(A_Args.Length && A_Args[1] = "--check" ? ["--check"] : ["--test-all"])
