#Requires AutoHotkey v2.0
#Include ..\common\InputCoordinator.ahk
#Include ..\rules\RuleEngine.ahk

class AutoSwitchFeature {
    __New(settingsProvider, rulesProvider, adapters, isEnabled) {
        this.settingsProvider := settingsProvider, this.rulesProvider := rulesProvider
        this.adapters := adapters, this.isEnabled := isEnabled
        this.gate := adapters.gate, this.lastWindow := "", this.lastProcess := ""
        this.lastTitle := "", this.lastTitleKnown := false
        this.lastMatch := RuleEngine.NoMatch(), this.dirty := true, this.forceNext := true
        this.guardedWindow := "", this.onResult := (*) => 0
    }

    ConfigChanged() => this.dirty := true
    RequestReevaluation() => (this.forceNext := true, this.dirty := true)
    Reevaluate() {
        this.RequestReevaluation()
        return this.Tick()
    }

    Tick(*) {
        if !this.isEnabled.Call()
            return {ok: false, reason: "Paused"}
        if !this.gate.TryEnter("Auto")
            return {ok: false, reason: "Busy"}
        try {
            context := this.adapters.contexts.Capture()
            if !context.hwnd || !context.processId || context.processName = ""
                return {ok: false, reason: "ContextUnavailable"}
            windowKey := AutoSwitchFeature.WindowKey(context)
            entered := windowKey != this.lastWindow
            if this.guardedWindow != "" && this.guardedWindow != windowKey
                this.guardedWindow := ""
            engine := this.rulesProvider.Call()
            titleKnown := !context.HasOwnProp("titleKnown") || context.titleKnown
            titleChanged := context.title != this.lastTitle || titleKnown != this.lastTitleKnown
            needsMatch := entered || this.forceNext || this.dirty || context.processName != this.lastProcess
                || (engine.HasTitleRules(context.processName) && titleChanged)
            if !needsMatch
                return {ok: true, reason: "Unchanged"}
            matched := engine.Match(context)
            apply := entered || this.forceNext || !RuleEngine.SameMatch(this.lastMatch, matched)
            this.Remember(context, matched) ; Consume an attempt before the IME call.
            this.dirty := false, this.forceNext := false
            if this.guardedWindow = windowKey
                return {ok: true, reason: "CandidatesProtected"}
            if !apply
                return {ok: true, reason: "Unchanged"}
            if !matched.matched || matched.mode = "Ignore"
                return {ok: true, reason: matched.matched ? "Ignored" : "NoMatch"}
            ; No retries during this window/rule match. No activation or key presses.
            result := this.adapters.ime.EnsureMode(context.hwnd, matched.mode,
                () => this.isEnabled.Call() && this.rulesProvider.Call() = engine)
            this.onResult.Call(result)
            return result
        } catch {
            ; A provider failure is consumed too, avoiding a permanent polling loop.
            this.dirty := false, this.forceNext := false
            return {ok: false, reason: "AutoSwitchFailed"}
        } finally {
            this.gate.Leave("Auto")
        }
    }

    ObserveManual(outcome, target := 0) {
        ; Called while the manual operation still owns the coordinator. Resuming
        ; polling must not immediately restore the previous automatic mode.
        if outcome.reason = "NoSelection" || outcome.reason = "SelectionUnknown" || outcome.reason = "IgnoredOtherLanguage"
            return
        context := this.adapters.contexts.Capture()
        if !context.hwnd || !context.processId
            return
        this.Remember(context, this.rulesProvider.Call().Match(context))
        this.dirty := false, this.forceNext := false
        if outcome.HasOwnProp("changed") && outcome.changed {
            original := IsObject(target) && target.HasOwnProp("hwnd") ? target : context
            this.guardedWindow := AutoSwitchFeature.WindowKey(original)
        }
    }

    Remember(context, matched) {
        this.lastWindow := AutoSwitchFeature.WindowKey(context)
        this.lastProcess := context.processName, this.lastTitle := context.title
        this.lastTitleKnown := !context.HasOwnProp("titleKnown") || context.titleKnown
        this.lastMatch := matched
    }

    static WindowKey(context) => context.hwnd ":" context.processId
}
