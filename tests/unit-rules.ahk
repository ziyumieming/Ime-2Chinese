#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\rules\RuleEngine.ahk
#Include ..\src\config\Defaults.ahk
#Include ..\src\config\HotkeySpec.ahk
#Include ..\src\config\ConfigStore.ahk
#Include TestAssert.ahk

Context(process, title := "") => {processName: process, title: title}
MakeRule(id, process, title := "", mode := "Chinese") => {id: id, process: process, titleContains: title, mode: mode}

RunTests()
RunTests() {
    try {
        rules := [MakeRule("Private", "MSEDGE.EXE", "Private", "Ignore"),
            MakeRule("ChinesePage", "msedge.exe", "中文"),
            MakeRule("Browser", "msedge.exe", "", "English"), MakeRule("Notes", "notepad.exe")]
        engine := RuleEngine(rules)
        TestAssert.Equal(engine.Match(Context("MsEdge.exe", "PRIVATE 中文")).mode, "Ignore", "first exception wins")
        TestAssert.Equal(engine.Match(Context("msedge.exe", "中文 - Edge")).ruleId, "ChinesePage", "title overrides general")
        TestAssert.Equal(engine.Match(Context("msedge.exe", "Other page")).mode, "English", "general fallback")
        TestAssert.Equal(engine.Match(Context("notepad.exe")).mode, "Chinese", "process without title")
        TestAssert.Equal(engine.Match(Context("edge.exe")).mode, "NoMatch", "process is exact")
        TestAssert.Equal(engine.Match(Context("C:\msedge.exe")).matched, false, "paths do not match filename")
        TestAssert.Equal(engine.Match(Context("other-msedge.exe")).matched, false, "process not substring")
        TestAssert.Equal(engine.Match(Context("msedge.exe", "")).ruleId, "Browser", "known empty title uses fallback")
        TestAssert.Equal(engine.HasTitleRules("MSEDGE.exe"), true, "title rules lookup ignores case")
        TestAssert.Equal(engine.HasTitleRules("notepad.exe"), false, "process-only rule needs no title reevaluation")
        TestAssert.Equal(engine.HasTitleRules("other.exe"), false, "unknown process needs no title reevaluation")
        reversed := RuleEngine([rules[3], rules[1], rules[2]])
        TestAssert.Equal(reversed.Match(Context("msedge.exe", "Private")).mode, "English", "no implicit specificity sorting")
        unicodeEngine := RuleEngine([MakeRule("Unicode", "记事本.exe", "Ä 中文 = 标题")])
        TestAssert.Equal(unicodeEngine.Match(Context("记事本.EXE", "prefix ä 中文 = 标题 suffix")).matched, true, "Unicode and equals literal contains")
        literal := RuleEngine([MakeRule("Literal", "app.exe", ".*")])
        TestAssert.Equal(literal.Match(Context("app.exe", "Anything")).matched, false, "not a regex")
        TestAssert.Equal(literal.Match(Context("app.exe", "Text .* suffix")).matched, true, "literal punctuation matches")
        TestAssert.Equal(RuleEngine([]).Match(Context("notepad.exe")).mode, "NoMatch", "empty defaults do nothing")
        missingProcess := {processName: "msedge.exe", title: "Private", processKnown: false}
        TestAssert.Equal(engine.Match(missingProcess).reason, "ProcessUnavailable", "failed read not accepted")
        TestAssert.Equal(engine.Match(Context("")).reason, "ProcessUnavailable", "empty process unavailable")
        missingTitle := {processName: "msedge.exe", title: "", titleKnown: false}
        TestAssert.Equal(engine.Match(missingTitle).reason, "TitleUnavailable", "unknown exception cannot fall through")
        missingTitle.processName := "notepad.exe"
        TestAssert.Equal(engine.Match(missingTitle).ruleId, "Notes", "process rule works without title")
        missingTitle.processName := "other.exe"
        TestAssert.Equal(engine.Match(missingTitle).reason, "NoMatch", "unrelated title rule does not block")
        missingTitle.processName := "msedge.exe"
        TestAssert.Equal(reversed.Match(missingTitle).ruleId, "Browser", "earlier broad rule needs no title")

        before := engine.Match(Context("msedge.exe", "中文 - before"))
        refreshed := engine.Match(Context("msedge.exe", "中文 - after"))
        TestAssert.Equal(RuleEngine.SameMatch(before, refreshed), true, "same-rule title refresh preserves manual choice")
        renamed := RuleEngine([MakeRule("chinesepage", "MSEDGE.EXE", "中文", "chinese")])
        TestAssert.Equal(RuleEngine.SameMatch(before, renamed.Match(Context("msedge.exe", "中文"))), true, "case-only edits do not change match")
        reordered := RuleEngine([rules[4], rules[2], rules[1], rules[3]])
        TestAssert.Equal(RuleEngine.SameMatch(before, reordered.Match(Context("msedge.exe", "中文"))), true, "index change keeps stable identity")
        different := RuleEngine([MakeRule("OtherChinese", "msedge.exe", "中文")])
        TestAssert.Equal(RuleEngine.SameMatch(before, different.Match(Context("msedge.exe", "中文"))), false, "different rules with same mode are distinct")
        changedMode := RuleEngine([MakeRule("ChinesePage", "msedge.exe", "中文", "English")])
        TestAssert.Equal(RuleEngine.SameMatch(before, changedMode.Match(Context("msedge.exe", "中文"))), false, "same-ID action edit is relevant")
        changedTitle := RuleEngine([MakeRule("ChinesePage", "msedge.exe", "中")])
        TestAssert.Equal(RuleEngine.SameMatch(before, changedTitle.Match(Context("msedge.exe", "中文"))), false, "same-ID criteria edit is relevant")
        changedProcess := RuleEngine([MakeRule("ChinesePage", "other.exe", "中文")])
        TestAssert.Equal(RuleEngine.SameMatch(before, changedProcess.Match(Context("other.exe", "中文"))), false, "same-ID process edit is relevant")
        ignored := engine.Match(Context("msedge.exe", "Private")), unmatched := engine.Match(Context("none.exe"))
        TestAssert.Equal(ignored.matched, true, "Ignore has identity")
        TestAssert.Equal(RuleEngine.SameMatch(ignored, unmatched), false, "Ignore distinct from no match")
        TestAssert.Equal(RuleEngine.SameMatch(unmatched, RuleEngine.NoMatch("ProcessUnavailable")), true, "both absent decisions do nothing")
        rules[2].mode := "English", rules.Push(MakeRule("Late", "late.exe"))
        TestAssert.Equal(engine.Match(Context("msedge.exe", "中文")).mode, "Chinese", "candidate mutation leaves compiled rules intact")
        before.mode := "Ignore"
        TestAssert.Equal(engine.Match(Context("msedge.exe", "中文")).mode, "Chinese", "result mutation leaves compiled rules intact")
        TestAssert.Equal(engine.Match(Context("late.exe")).matched, false, "source array mutation leaves engine intact")
        TestAssert.Throws(() => RuleEngine([MakeRule("dup", "a.exe"), MakeRule("DUP", "b.exe")]), "duplicate case-insensitive identity rejected")
        TestAssert.Throws(() => RuleEngine([MakeRule("bad.id", "a.exe")]), "invalid identity rejected")
        TestAssert.Throws(() => RuleEngine([MakeRule("bad", "C:\a.exe")]), "path rule rejected")
        TestAssert.Throws(() => RuleEngine([MakeRule("bad", "a.exe", "", "Other")]), "invalid action rejected")
        cfg := ConfigStore.Parse(FileRead(A_ScriptDir "\..\config\rules.example.ini", "UTF-8"))
        example := RuleEngine(cfg.rules)
        TestAssert.Equal(example.Match(Context("msedge.exe", "Private - Edge")).mode, "Ignore", "user example ignore")
        TestAssert.Equal(example.Match(Context("msedge.exe", "中文资料 - Edge")).mode, "Chinese", "user example Chinese")
        TestAssert.Equal(example.Match(Context("msedge.exe", "Other - Edge")).mode, "English", "user example English")
        TestAssert.Equal(example.Match(Context("notepad.exe", "Untitled")).mode, "Chinese", "user example notes")
        TestAssert.Equal(example.Match(Context("firefox.exe", "中文资料")).mode, "NoMatch", "user example unmatched")
        TestAssert.Finish("ordered matching, unknown context, stable identity and config examples")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
