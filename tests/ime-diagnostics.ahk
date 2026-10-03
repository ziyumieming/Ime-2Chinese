#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\WindowContext.ahk
#Include ..\src\system\ImeProfiles.ahk
#Include ..\src\system\ImeController.ahk

FileEncoding("UTF-8")

try {
    Diagnostics(A_Args)
} catch as err {
    FileAppend("error=" err.Message "`n", "*")
    ExitApp(1)
}
ExitApp(0)

Diagnostics(args) {
    if !args.Length || args[1] = "--help" {
        FileAppend("Read-only: --list | --inspect HWND`nWrite test: --mode Chinese|English HWND`nSession-wide experiment: --activate-session KIND HWND (can affect other windows)`nKINDS: SogouPinyin, MicrosoftPinyin`n", "*")
        return
    }
    if args[1] = "--list" {
        for profile in ImeProfiles.List() {
            FileAppend(Format("kind={} lang={:04X} enabled={} active={} type={} clsid={} guid={} name={}`n",
                profile.kind, profile.langId, profile.enabled, profile.active, profile.type,
                profile.clsid, profile.guid, profile.description), "*")
        }
        return
    }
    if args[1] = "--inspect" && args.Length = 2 {
        PrintStatus(ImeController().GetStatus(Integer(args[2])))
        return
    }
    if args[1] = "--mode" && args.Length = 3 {
        result := ImeController().EnsureMode(Integer(args[3]), args[2])
        FileAppend("ok=" result.ok "`nreason=" result.reason "`n", "*")
        if result.HasOwnProp("status")
            PrintStatus(result.status)
        if !result.ok
            ExitApp(2)
        return
    }
    if args[1] = "--activate-session" && args.Length = 3 {
        hwnd := Integer(args[3])
        ctx := WindowContext.Get(hwnd)
        if !WindowContext.IsCurrent(ctx)
            throw Error("TargetNotFocused")
        profile := ImeProfiles.Find(args[2])
        result := ImeProfiles.ActivateForSession(profile)
        FileAppend("scope=SessionWide`nok=" result.ok "`nreason=" result.reason "`n", "*")
        if !result.ok
            ExitApp(2)
        Sleep(150)
        PrintStatus(ImeController().GetStatus(hwnd))
        return
    }
    throw Error("Invalid diagnostic arguments; use --help")
}

PrintStatus(status) {
    ctx := WindowContext.Get(status.hwnd)
    FileAppend(Format("hwnd={}`nprocess={}`nfocusKnown={}`ncontrolHwnd={}`nhkl={:08X}`nprofileKind={}`nprofileScope={}`nimeHwnd={}`nopenStatus={}`nconversionMode={}`nmode={}`nreason={}`n",
        status.hwnd, ctx.processName, ctx.focusKnown, status.controlHwnd, status.hkl & 0xFFFFFFFF,
        status.profileKind, status.profileScope, status.imeHwnd,
        status.openStatus, status.conversionMode, status.mode, status.reason), "*")
}
