#Requires AutoHotkey v2.0

class ImeController {
    __New(messageTimeoutMs := 150, verificationTimeoutMs := 600) {
        if messageTimeoutMs < 1 || verificationTimeoutMs < 1
            throw ValueError("IME timeouts must be positive")
        this.messageTimeoutMs := messageTimeoutMs
        this.verificationTimeoutMs := verificationTimeoutMs
    }

    GetStatus(hwnd) {
        ctx := WindowContext.Get(hwnd)
        status := {mode: "Unknown", reason: "InvalidWindow", hwnd: hwnd,
            controlHwnd: ctx.controlHwnd, hkl: ctx.hkl, imeHwnd: 0,
            openStatus: -1, conversionMode: -1, profileKind: "Unknown", profileScope: "SessionHint"}
        if !ctx.threadId
            return status
        if (ctx.hkl & 0xFFFF) != 0x0804 {
            status.mode := "Unsupported"
            status.reason := "InputLanguageNotSupported"
            return status
        }
        try {
            profile := ImeProfiles.GetActive()
            status.profileKind := profile.langId = (ctx.hkl & 0xFFFF) ? profile.kind : "Unknown"
        }
        target := ctx.controlHwnd ? ctx.controlHwnd : hwnd
        status.imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", target, "Ptr")
        if !status.imeHwnd && target != hwnd
            status.imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
        if !status.imeHwnd {
            status.reason := "ImeWindowUnavailable"
            return status
        }
        open := this.Message(status.imeHwnd, 5)
        conversion := this.Message(status.imeHwnd, 1)
        if !open.ok || !conversion.ok {
            status.reason := "ImeQueryFailed"
            return status
        }
        status.openStatus := open.value
        status.conversionMode := conversion.value
        status.mode := ImeController.DecodeMode(open.value, conversion.value)
        status.reason := status.mode = "Unknown" ? "InvalidImeStatus" : "Observed"
        return status
    }

    EnsureChinese(hwnd) => this.EnsureMode(hwnd, "Chinese")
    EnsureEnglish(hwnd) => this.EnsureMode(hwnd, "English")

    EnsureMode(hwnd, mode) {
        if mode != "Chinese" && mode != "English"
            return {ok: false, reason: "InvalidMode"}
        ctx := WindowContext.Get(hwnd)
        if !WindowContext.IsCurrent(ctx)
            return {ok: false, reason: "TargetNotFocused"}
        before := this.GetStatus(hwnd)
        if before.mode = "Unknown" || before.mode = "Unsupported"
            return {ok: false, reason: before.reason, status: before}
        if before.profileKind != "SogouPinyin" && before.profileKind != "MicrosoftPinyin"
            return {ok: false, reason: "UnsupportedProfileHint", status: before}
        if before.mode = mode
            return {ok: true, reason: "AlreadyCorrect", status: before}
        conversion := mode = "Chinese" ? (before.conversionMode | 1) : (before.conversionMode & ~1)
        if !WindowContext.IsCurrent(ctx)
            return {ok: false, reason: "FocusChanged"}
        sent := this.Message(before.imeHwnd, 2, conversion)
        if !sent.ok
            return {ok: false, reason: "ImeWriteFailed"}
        if mode = "Chinese" && !before.openStatus {
            if !WindowContext.IsCurrent(ctx)
                return {ok: false, reason: "FocusChanged"}
            opened := this.Message(before.imeHwnd, 6, 1)
            if !opened.ok
                return {ok: false, reason: "ImeOpenFailed"}
        }
        deadline := A_TickCount + this.verificationTimeoutMs
        loop {
            if !WindowContext.IsCurrent(ctx)
                return {ok: false, reason: "FocusChanged"}
            after := this.GetStatus(hwnd)
            if after.mode = mode
                return {ok: true, reason: "Verified", status: after}
            if A_TickCount >= deadline
                return {ok: false, reason: "VerificationFailed", status: after}
            Sleep(20)
        }
    }

    Message(imeHwnd, command, value := 0) {
        result := 0
        DllCall("kernel32\SetLastError", "UInt", 0)
        sent := DllCall("user32\SendMessageTimeoutW", "Ptr", imeHwnd, "UInt", 0x0283,
            "UPtr", command, "Ptr", value, "UInt", 0x23, "UInt", this.messageTimeoutMs,
            "UPtr*", &result, "Ptr")
        return {ok: !!sent, value: result, error: sent ? 0 : A_LastError}
    }

    static DecodeMode(openStatus, conversionMode) {
        if (openStatus != 0 && openStatus != 1) || conversionMode < 0 || conversionMode > 0xFFFF
            return "Unknown"
        return openStatus && (conversionMode & 1) ? "Chinese" : "English"
    }
}
