#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\config\Defaults.ahk
#Include ..\src\common\TextRules.ahk
#Include ..\src\system\ClipboardService.ahk
#Include ..\src\system\TextSender.ahk
#Include ..\src\features\RefeedFeature.ahk
#Include FakeInput.ahk
#Include TestAssert.ahk

class FeedbackSelection {
    __New() => this.state := "Selected"
    Check(*) => {state: this.state, token: 0}
    IsCurrent(*) => true
}
class FeedbackIme extends PreparedIme {
    __New() {
        super.__New()
        this.allowed := true, this.readyCalls := 0, this.failReadyAt := 0
    }
    CheckRefeedContext(*) => {ok: this.allowed, reason: this.allowed ? "Allowed" : "IgnoredOtherLanguage"}
    ReadyForInput(*) {
        this.readyCalls += 1
        return {ok: this.readyCalls != this.failReadyAt, reason: "ReadinessFailed"}
    }
}
class FeedbackFixture {
    __New() {
        this.settings := Defaults.Create(), this.contexts := FakeContext(), this.keys := FakeKeys()
        this.clipDriver := FakeClipboardDriver(), this.output := FakeOutput()
        this.selection := FeedbackSelection(), this.ime := FeedbackIme()
        this.feature := RefeedFeature(() => this.settings, {contexts: this.contexts, keys: this.keys,
            clipboard: ClipboardService(this.clipDriver), sender: TextSender(this.output),
            ime: this.ime, selection: this.selection}, () => true)
    }
}
RunTests()
RunTests() {
    try {
        fixture := FeedbackFixture(), fixture.selection.state := "Empty"
        fixture.feature.lastOriginal := "saved"
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "NoSelection", "empty selection is a quiet no-op")
        TestAssert.Equal(fixture.clipDriver.copies, 0, "empty selection sends no Ctrl+C")
        TestAssert.Equal(fixture.clipDriver.sequenceNumber, 10, "empty selection never touches clipboard")
        TestAssert.Equal(fixture.output.deletes, 0, "empty selection does not delete")
        TestAssert.Equal(fixture.feature.lastOriginal, "saved", "empty selection preserves recovery")
        fixture := FeedbackFixture(), fixture.selection.state := "Unknown"
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "SelectionUnknown", "unobservable selection does not guess")
        TestAssert.Equal(fixture.clipDriver.copies, 0, "unknown selection sends no copy")
        fixture := FeedbackFixture(), fixture.ime.allowed := false
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "IgnoredOtherLanguage", "other language is a quiet no-op")
        TestAssert.Equal(fixture.clipDriver.sequenceNumber, 10, "other language leaves clipboard untouched")
        TestAssert.Equal(fixture.output.deletes, 0, "other language does not delete")
        fixture := FeedbackFixture()
        TestAssert.Equal(fixture.feature.ConvertSelection().ok, true, "normal feedback pipeline")
        TestAssert.Equal(fixture.ime.readyCalls, 2, "readiness checked after final copy and deletion")
        fixture := FeedbackFixture(), fixture.ime.failReadyAt := 1
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "ReadinessFailed", "pre-delete readiness failure")
        TestAssert.Equal(fixture.output.deletes, 0, "pre-delete readiness preserves text")
        fixture := FeedbackFixture(), fixture.ime.failReadyAt := 2
        result := fixture.feature.ConvertSelection()
        TestAssert.Equal(result.reason, "ReadinessFailed", "post-delete readiness failure")
        TestAssert.Equal(fixture.output.letters, "", "no first character before readiness")
        TestAssert.Equal(result.changed, true, "deletion explicitly recorded")
        TestAssert.Equal(fixture.feature.lastOriginal, "ni hao", "post-delete failure keeps original")
        fixture := FeedbackFixture()
        fixture.ime.onPrepare := (*) => fixture.selection.state := "Empty"
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "SelectionChanged", "collapsed selection caught without another copy")
        TestAssert.Equal(fixture.output.deletes, 0, "collapsed selection cannot delete neighbor text")
        TestAssert.Finish("user feedback: empty selection, language skip and first-character readiness")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
