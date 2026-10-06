#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\App.ahk

; Production entry: manual refeed/recovery plus settings and diagnostics.
; Historical automatic window switching remains explicit and frozen.
App().Run(A_Args)
