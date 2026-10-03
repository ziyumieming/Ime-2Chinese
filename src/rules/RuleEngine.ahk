#Requires AutoHotkey v2.0

; Pure matching: no window reads, timers, logging or IME operations.
class RuleEngine {
    __New(rules) {
        this._rules := [], this._titleProcesses := Map(), identities := Map()
        modes := Map("chinese", "Chinese", "english", "English", "ignore", "Ignore")
        for rule in rules {
            identity := StrLower(rule.id), process := StrLower(rule.process)
            if !RegExMatch(identity, "^[a-z0-9_-]+$") || identities.Has(identity)
                throw ValueError("规则编号须唯一，且只含字母、数字、下划线或连字符。")
            if !RegExMatch(process, "^[^\\/:*?" Chr(34) "<>|\s]+\.exe$")
                throw ValueError("规则须指定不含路径的进程名。")
            mode := StrLower(rule.mode)
            if !modes.Has(mode)
                throw ValueError("规则动作无效。")
            identities[identity] := true
            ; Copy values: editing candidate config or a result cannot mutate the engine.
            titleContains := StrLower(rule.titleContains)
            this._rules.Push({ruleId: rule.id, identity: identity, process: process,
                titleContains: titleContains, mode: modes[mode]})
            if titleContains != ""
                this._titleProcesses[process] := true
        }
    }

    HasTitleRules(processName) => this._titleProcesses.Has(StrLower(processName))

    Match(context) {
        if (context.HasOwnProp("processKnown") && !context.processKnown) || context.processName = ""
            return RuleEngine.NoMatch("ProcessUnavailable")
        process := StrLower(context.processName)
        titleKnown := !context.HasOwnProp("titleKnown") || context.titleKnown
        title := titleKnown ? StrLower(context.title) : ""
        for index, rule in this._rules {
            if process != rule.process
                continue
            if rule.titleContains != "" {
                ; An unreadable earlier exception must not fall through to a broad rule.
                if !titleKnown
                    return RuleEngine.NoMatch("TitleUnavailable")
                if !InStr(title, rule.titleContains, true)
                    continue
            }
            return {matched: true, ruleId: rule.ruleId, identity: rule.identity,
                process: rule.process, titleContains: rule.titleContains,
                mode: rule.mode, index: index, reason: "Matched"}
        }
        return RuleEngine.NoMatch()
    }

    static NoMatch(reason := "NoMatch") => {matched: false, ruleId: "", identity: "",
        process: "", titleContains: "", mode: "NoMatch", index: 0, reason: reason}

    ; Ignore and NoMatch are distinct. Order, title text and unrelated config are
    ; deliberately absent; changing the matched rule's criteria/action is relevant.
    static SameMatch(previous, current) {
        if previous.matched != current.matched
            return false
        if !previous.matched
            return true
        return previous.identity == current.identity && previous.mode == current.mode
            && previous.process == current.process && previous.titleContains == current.titleContains
    }
}
