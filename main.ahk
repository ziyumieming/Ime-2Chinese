#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\App.ahk

; Bootstrap only. Feature registration starts after the P0 compatibility gate.
App().Run(A_Args)
