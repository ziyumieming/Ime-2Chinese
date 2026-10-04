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
        this.BeginTrace("Refeed")
        outcome := {ok: false, reason: "SystemError", changed: false}
        context := 0
        try {
            settings := this.settingsProvider.Call()
            context := this.Observe("CaptureTarget", () => this.adapters.contexts.Capture())
            target := this.Observe("EditableCheck", () => this.adapters.editable.Check(context))
            if target.state = "Editable"
                this.activeEditable := target
            if target.state != "Editable"
                outcome.reason := target.reason
            else if !this.Observe("ReleaseKeys", () => this.adapters.keys.Release())
                outcome.reason := "HotkeyReleaseTimeout"
            else if !this.CanContinue(context)
                outcome.reason := "TargetChanged"
            else if !(allowed := this.Observe("LanguageCheck", () => this.adapters.ime.CheckRefeedContext(context))).ok
                outcome.reason := allowed.reason
            else if (selection := this.Observe("SelectionCheck", () => this.adapters.selection.Check(context))).state != "Selected"
                outcome.reason := selection.state = "Empty" ? "NoSelection" : "SelectionUnknown"
            else {
                this.activeEditable := target
                this.activeSelection := selection
                this.Observe("ClipboardBegin", () => this.adapters.clipboard.Begin())
                outcome := this.Convert(context, settings)
            }
        } catch as err {
            this.ErrorTrace(err)
            outcome.reason := "SystemError"
        } finally {
            try {
                cleanup := this.adapters.clipboard.End()
                this.Trace("ClipboardCleanup", cleanup)
                outcome.clipboardReason := cleanup.reason
            } catch as err {
                this.ErrorTrace(err)
                outcome.clipboardReason := "ClipboardRestoreFailed"
            }
            this.Finish(outcome, context)
        }
        return outcome
    }

    Convert(context, settings) {
        copied := this.Observe("CopySelection", () => this.adapters.clipboard.ReadSelection(context, settings.copyTimeoutMs, () => this.CanContinue(context)))
        if !copied.ok
            return {ok: false, reason: copied.reason, changed: false}
        validated := TextRules.Validate(copied.text, settings.maxRefeedLength)
        this.Trace("ValidateText", {ok: validated.ok, reason: validated.reason, selectionLength: StrLen(copied.text)})
        if !validated.ok
            return {ok: false, reason: validated.reason, changed: false}
        if !this.CanContinue(context)
            return {ok: false, reason: "TargetChanged", changed: false}
        this.Trace("RequestedMode", {mode: "Chinese", profileHint: settings.refeedTarget})
        ime := this.Observe("PrepareIme", () => this.adapters.ime.PrepareRefeed(context, settings.refeedTarget, () => this.CanContinue(context)))
        if !ime.ok
            return {ok: false, reason: ime.reason, changed: false}
        if !this.CanContinue(context)
            return {ok: false, reason: "TargetChanged", changed: false}
        ; IME switching may collapse selection; copy again before deleting it.
        verified := this.Observe("VerifySelection", () => this.adapters.clipboard.ReadSelection(context, settings.copyTimeoutMs, () => this.CanContinue(context)))
        if !verified.ok
            return {ok: false, reason: verified.reason, changed: false}
        if verified.text != validated.original
            return {ok: false, reason: "SelectionChanged", changed: false}
        if !this.CanContinue(context) || !this.adapters.clipboard.OwnsCurrent()
            return {ok: false, reason: "TargetChanged", changed: false}
        ready := this.Observe("ReadyBeforeDelete", () => this.adapters.ime.ReadyForInput(context, () => this.CanContinue(context)))
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
        this.Trace("DeleteAttempt", {cacheAvailable: true, deleteAttempted: true})
        try deletion := this.Observe("DeleteSelection", () => this.adapters.sender.DeleteSelection(canContinue))
        catch as err {
            this.ErrorTrace(err)
            return {ok: false, reason: "DeleteFailed", changed: true}
        }
        if !deletion.ok {
            this.lastOriginal := previous
            return deletion
        }
        try {
            ; Copy/Backspace may change the app's input state. Never send the
            ; first letter on a single immediate acknowledgement of Chinese.
            ready := this.Observe("ReadyAfterDelete", () => this.adapters.ime.ReadyForInput(context, canContinue))
            if !ready.ok
                return {ok: false, reason: ready.reason, changed: true}
            sent := this.Observe("SendLetters", () => this.adapters.sender.SendLetters(validated.letters, settings.sendIntervalMs, canContinue))
            return {ok: sent.ok, reason: sent.reason, changed: true, sent: sent.sent}
        } catch as err {
            this.ErrorTrace(err)
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
        this.BeginTrace("Recover")
        outcome := {ok: false, reason: "RecoverFailed"}, context := 0
        try {
            context := this.Observe("CaptureTarget", () => this.adapters.contexts.Capture())
            target := this.Observe("EditableCheck", () => this.adapters.editable.Check(context))
            if target.state != "Editable"
                outcome := {ok: false, reason: target.reason}
            else if !this.Observe("ReleaseKeys", () => this.adapters.keys.Release())
                outcome := {ok: false, reason: "HotkeyReleaseTimeout"}
            else {
                this.activeEditable := target
                outcome := this.Observe("SendOriginal", () => this.adapters.sender.SendOriginal(this.lastOriginal, () => this.CanContinue(context)))
            }
        } catch as err {
            this.ErrorTrace(err)
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
            if this.HasOwnProp("activeTrace") {
                outcome.operationId := this.activeTrace.id
                outcome.cacheAvailable := this.lastOriginal != ""
                try this.adapters.logger.Finish(this.activeTrace, outcome)
                this.DeleteProp("activeTrace")
            }
            this.busy := false
            this.gate.Leave("Manual")
        }
    }

    CanContinue(context) => this.isEnabled.Call() && this.adapters.contexts.IsCurrent(context)
        && (!this.HasOwnProp("activeEditable") || this.adapters.editable.IsCurrent(this.activeEditable, context))
        && (!this.HasOwnProp("activeSelection") || this.adapters.selection.IsCurrent(this.activeSelection))

    BeginTrace(event) {
        if this.adapters.HasOwnProp("logger")
            try this.activeTrace := this.adapters.logger.Begin(event)
    }
    Trace(stage, fields) {
        if this.HasOwnProp("activeTrace")
            try this.adapters.logger.Stage(this.activeTrace, stage, fields)
    }
    Observe(stage, callback) {
        this.traceStage := stage
        this.Trace(stage, {phase: "Begin"})
        result := callback.Call()
        this.Trace(stage, IsObject(result) ? result : {value: result})
        return result
    }
    ErrorTrace(err) => this.Trace("Exception", {stage: this.HasOwnProp("traceStage") ? this.traceStage : "Unknown",
        error: err.Message, file: err.File, line: err.Line, extra: err.Extra})
}
