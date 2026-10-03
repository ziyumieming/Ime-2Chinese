#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\App.ahk

; Normal entry is configuration/tray only. Input features use explicit MVP flags.
App().Run(A_Args)
