#Requires AutoHotkey v2.0

; One current-user Startup shortcut. No elevation, service or scheduled task.
class StartupService {
    __New(directory := unset) {
        this.directory := IsSet(directory) ? directory : A_Startup
        this.path := this.directory "\Ime-2Chinese.lnk"
        this.marker := "Ime-2Chinese managed startup"
        SplitPath(A_LineFile, , &sourceDirectory)
        pathBuffer := Buffer(32768 * 2, 0)
        DllCall("kernel32\GetFullPathNameW", "WStr", sourceDirectory "\..\..\main.ahk", "UInt", 32768, "Ptr", pathBuffer, "Ptr", 0)
        this.entry := A_IsCompiled ? A_ScriptFullPath : StrGet(pathBuffer, "UTF-16")
    }
    Snapshot() {
        exists := !!FileExist(this.path)
        if exists {
            FileGetShortcut(this.path, , , , &description)
            if description != this.marker
                throw Error("启动目录存在同名的非本程序快捷方式；未覆盖。")
        }
        return {exists: exists, data: exists ? FileRead(this.path, "RAW") : 0}
    }
    Apply(enabled, mode := "") {
        if FileExist(this.path)
            this.Snapshot() ; Refuse an unrelated same-name shortcut even when disabling.
        if !enabled {
            if FileExist(this.path)
                FileDelete(this.path)
            return
        }
        if !FileExist(this.entry) || (!A_IsCompiled && !FileExist(A_AhkPath))
            throw Error("找不到自启所需的程序文件。")
        DirCreate(this.directory)
        target := A_IsCompiled ? this.entry : A_AhkPath
        arguments := A_IsCompiled ? mode : '/restart "' this.entry '"' (mode != "" ? " " mode : "")
        temporary := this.path ".tmp-" DllCall("GetCurrentProcessId", "UInt") ".lnk"
        try {
            FileCreateShortcut(target, temporary, , arguments, this.marker)
            FileGetShortcut(temporary, &actualTarget, , &actualArguments, &description)
            if actualTarget != target || actualArguments != arguments || description != this.marker
                throw Error("自启快捷方式验证失败。")
            FileMove(temporary, this.path, true)
        } finally {
            if FileExist(temporary)
                FileDelete(temporary)
        }
    }
    Restore(snapshot) {
        if snapshot.exists {
            outputFile := FileOpen(this.path, "w")
            if !outputFile
                throw Error("无法恢复原自启设置。")
            try outputFile.RawWrite(snapshot.data)
            finally outputFile.Close()
        } else if FileExist(this.path)
            FileDelete(this.path)
    }
}
