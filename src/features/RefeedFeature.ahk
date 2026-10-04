#Requires AutoHotkey v2.0
#Include ..\common\InputCoordinator.ahk
#Include ..\system\EditableProbe.ahk

class RefeedFeature {
    __New(settingsProvider, adapters, isEnabled) {
        this.settingsProvider := settingsProvider, this.adapters := adapters
        this.isEnabled := isEnabled, this.busy := false, this.lastOriginal := ""
        this.gate := adapters.HasOwnProp("gate") ? adapters.gate : InputCoordinator()
        this.onFinish := (*) => 0
        if !adapters.HasOwnProp("editable")
            adapters.editable := EditableProbe()
    }

    ConvertSelection(*) {
        if this.busy
            return {ok: false, reason: "Busy", changed: false}
        if !this.isEnabled.Call()
            return {ok: false, reason: "Paused", changed: false}
        if !this.gate.TryEnter("Manual")
            return {ok: false, reason: "Busy", changed: false}
        this.busy := true
        outcome := {ok: false, reason: "SystemError", changed: false}
        context := 0
        try {
            settings := this.settingsProvider.Call()
            context := this.adapters.contexts.Capture()
            target := this.adapters.editable.Check(context)
            if target.state = "Editable"
                this.activeEditable := target
            if target.state != "Editable"
                outcome.reason := target.reason
            else if !this.adapters.keys.Release()
                outcome.reason := "HotkeyReleaseTimeout"
            else if !this.CanContinue(context)
                outcome.reason := "TargetChanged"
            else if !(allowed := this.adapters.ime.CheckRefeedContext(context)).ok
                outcome.reason := allowed.reason
            else if (selection := this.adapters.selection.Check(context)).state != "Selected"
                outcome.reason := selection.state = "Empty" ? "NoSelection" : "SelectionUnknown"
            else {
                this.activeEditable := target
                this.activeSelection := selection
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
            this.Finish(outcome, context)
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
        ime := this.adapters.ime.PrepareRefeed(context, settings.refeedTarget, () => this.CanContinue(context))
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
        ready := this.adapters.ime.ReadyForInput(context, () => this.CanContinue(context))
        if !ready.ok
            return {ok: false, reason: ready.reason, changed: false}
        if this.adapters.selection.Check(context).state != "Selected"
            return {ok: false, reason: "SelectionChanged", changed: false}
        if !this.adapters.clipboard.OwnsCurrent()
            return {ok: false, reason: "ClipboardChanged", changed: false}
        if !this.CanContinue(context)
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
            ; Copy/Backspace may change the app's input state. Never send the
            ; first letter on a single immediate acknowledgement of Chinese.
            ready := this.adapters.ime.ReadyForInput(context, canContinue)
            if !ready.ok
                return {ok: false, reason: ready.reason, changed: true}
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
        if !this.gate.TryEnter("Manual")
            return {ok: false, reason: "Busy"}
        this.busy := true
        outcome := {ok: false, reason: "RecoverFailed"}, context := 0
        try {
            context := this.adapters.contexts.Capture()
            target := this.adapters.editable.Check(context)
            if target.state != "Editable"
                outcome := {ok: false, reason: target.reason}
            else if !this.adapters.keys.Release()
                outcome := {ok: false, reason: "HotkeyReleaseTimeout"}
            else {
                this.activeEditable := target
                outcome := this.adapters.sender.SendOriginal(this.lastOriginal, () => this.CanContinue(context))
            }
        } catch {
            outcome := {ok: false, reason: "RecoverFailed"}
        } finally {
            this.Finish(outcome, context)
        }
        return outcome
    }

    Finish(outcome, context) {
        if this.HasOwnProp("activeSelection")
            this.DeleteProp("activeSelection")
        if this.HasOwnProp("activeEditable")
            this.DeleteProp("activeEditable")
        try this.onFinish.Call(outcome, context)
        catch
            outcome.coordinationReason := "CoordinationFailed"
        finally {
            this.busy := false
            this.gate.Leave("Manual")
        }
    }

    CanContinue(context) => this.isEnabled.Call() && this.adapters.contexts.IsCurrent(context)
        && (!this.HasOwnProp("activeEditable") || this.adapters.editable.IsCurrent(this.activeEditable, context))
        && (!this.HasOwnProp("activeSelection") || this.adapters.selection.IsCurrent(this.activeSelection))
}
