#Requires AutoHotkey v2.0

class RefeedFeature {
    __New(settingsProvider, adapters, isEnabled) {
        this.settingsProvider := settingsProvider, this.adapters := adapters
        this.isEnabled := isEnabled, this.busy := false, this.lastOriginal := ""
    }

    ConvertSelection(*) {
        if this.busy
            return {ok: false, reason: "Busy", changed: false}
        if !this.isEnabled.Call()
            return {ok: false, reason: "Paused", changed: false}
        this.busy := true
        outcome := {ok: false, reason: "SystemError", changed: false}
        try {
            settings := this.settingsProvider.Call()
            context := this.adapters.contexts.Capture()
            if !this.adapters.keys.Release()
                outcome.reason := "HotkeyReleaseTimeout"
            else if !this.CanContinue(context)
                outcome.reason := "TargetChanged"
            else {
                this.adapters.clipboard.Begin()
                outcome := this.Convert(context, settings)
            }
        } catch {
            outcome.reason := "SystemError"
        } finally {
            try {
                cleanup := this.adapters.clipboard.End()
                outcome.clipboardReason := cleanup.reason
            } catch {
                outcome.clipboardReason := "ClipboardRestoreFailed"
            }
            this.busy := false
        }
        return outcome
    }

    Convert(context, settings) {
        copied := this.adapters.clipboard.ReadSelection(context, settings.copyTimeoutMs, () => this.CanContinue(context))
        if !copied.ok
            return {ok: false, reason: copied.reason, changed: false}
        validated := TextRules.Validate(copied.text, settings.maxRefeedLength)
        if !validated.ok
            return {ok: false, reason: validated.reason, changed: false}
        if !this.CanContinue(context)
            return {ok: false, reason: "TargetChanged", changed: false}
        ime := this.adapters.ime.PrepareRefeed(context, settings.refeedTarget)
        if !ime.ok
            return {ok: false, reason: ime.reason, changed: false}
        if !this.CanContinue(context)
            return {ok: false, reason: "TargetChanged", changed: false}
        ; IME switching may collapse selection; copy again before deleting it.
        verified := this.adapters.clipboard.ReadSelection(context, settings.copyTimeoutMs, () => this.CanContinue(context))
        if !verified.ok
            return {ok: false, reason: verified.reason, changed: false}
        if verified.text != validated.original
            return {ok: false, reason: "SelectionChanged", changed: false}
        if !this.CanContinue(context) || !this.adapters.clipboard.OwnsCurrent()
            return {ok: false, reason: "TargetChanged", changed: false}
        canContinue := () => this.CanContinue(context)
        ; Cache at the first destructive attempt, and retain it for partial failure.
        previous := this.lastOriginal
        this.lastOriginal := validated.original
        try deletion := this.adapters.sender.DeleteSelection(canContinue)
        catch
            return {ok: false, reason: "DeleteFailed", changed: true}
        if !deletion.ok {
            this.lastOriginal := previous
            return deletion
        }
        try {
            sent := this.adapters.sender.SendLetters(validated.letters, settings.sendIntervalMs, canContinue)
            return {ok: sent.ok, reason: sent.reason, changed: true, sent: sent.sent}
        } catch {
            return {ok: false, reason: "SendFailed", changed: true}
        }
    }

    RecoverLast(*) {
        if this.busy
            return {ok: false, reason: "Busy"}
        if !this.isEnabled.Call()
            return {ok: false, reason: "Paused"}
        if this.lastOriginal = ""
            return {ok: false, reason: "NoCachedOriginal"}
        this.busy := true
        try {
            context := this.adapters.contexts.Capture()
            if !this.adapters.keys.Release()
                return {ok: false, reason: "HotkeyReleaseTimeout"}
            return this.adapters.sender.SendOriginal(this.lastOriginal, () => this.CanContinue(context))
        } catch {
            return {ok: false, reason: "RecoverFailed"}
        } finally {
            this.busy := false
        }
    }

    CanContinue(context) => this.isEnabled.Call() && this.adapters.contexts.IsCurrent(context)
}
