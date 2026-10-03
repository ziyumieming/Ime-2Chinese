#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\config\Defaults.ahk
#Include ..\src\common\TextRules.ahk
#Include ..\src\system\ClipboardService.ahk
#Include ..\src\system\TextSender.ahk
#Include ..\src\features\RefeedFeature.ahk
#Include FakeInput.ahk
#Include TestAssert.ahk

class RefeedFixture {
    __New() {
        this.settings := Defaults.Create(), this.enabled := true
        this.contexts := FakeContext(), this.keys := FakeKeys(), this.clipboardDriver := FakeClipboardDriver()
        this.output := FakeOutput(), this.ime := PreparedIme()
        this.clipboard := ClipboardService(this.clipboardDriver)
        this.feature := RefeedFeature(() => this.settings,
            {contexts: this.contexts, keys: this.keys, clipboard: this.clipboard,
             ime: this.ime, sender: TextSender(this.output)}, () => this.enabled)
    }
}

RunTests()
RunTests() {
    try {
        fixture := RefeedFixture()
        fixture.clipboardDriver.selection := "Ni hao`n"
        result := fixture.feature.ConvertSelection()
        TestAssert.Equal(result.ok, true, "normal pipeline")
        TestAssert.Equal(fixture.ime.calls, 1, "IME verified before delete")
        TestAssert.Equal(fixture.clipboardDriver.copies, 2, "selection checked after IME switch")
        TestAssert.Equal(fixture.output.deletes, 1, "one deletion")
        TestAssert.Equal(fixture.output.letters, "Nihao", "case preserved, no candidate commit key")
        TestAssert.Equal(fixture.output.intervals[1], 10, "demo interval")
        TestAssert.Equal(fixture.feature.lastOriginal, "Ni hao`n", "full original cached")
        TestAssert.Equal(fixture.clipboardDriver.value.rich, "formatted", "pipeline restores rich clipboard")
        fixture.contexts.identity := 2
        TestAssert.Equal(fixture.feature.RecoverLast().ok, true, "recover into another target")
        fixture.feature.RecoverLast()
        TestAssert.Equal(fixture.output.literal.Length, 2, "repeat recover allowed")
        TestAssert.Equal(fixture.output.literal[2], "Ni hao`n", "recover preserves whitespace and case")
        for invalid in ["", " ", "ni1hao", "你好", "ni.hao"] {
            fixture := RefeedFixture()
            fixture.feature.lastOriginal := "earlier valid"
            fixture.clipboardDriver.selection := invalid
            TestAssert.Equal(fixture.feature.ConvertSelection().ok, false, "invalid request fails")
            TestAssert.Equal(fixture.output.deletes, 0, "invalid request does not delete")
            TestAssert.Equal(fixture.feature.lastOriginal, "earlier valid", "invalid request preserves old cache")
        }
        fixture := RefeedFixture()
        fixture.ime.ok := false
        fixture.feature.lastOriginal := "earlier valid"
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "TargetImeNotActive", "IME failure before delete")
        TestAssert.Equal(fixture.output.deletes, 0, "IME failure preserves selected text")
        TestAssert.Equal(fixture.feature.lastOriginal, "earlier valid", "IME failure preserves cache")
        fixture := RefeedFixture()
        fixture.clipboardDriver.secondSelection := "changed"
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "SelectionChanged", "switch collapsed/replaced selection")
        TestAssert.Equal(fixture.output.deletes, 0, "changed selection not deleted")
        fixture := RefeedFixture()
        fixture.ime.onPrepare := (*) => fixture.contexts.identity := 2
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "TargetChanged", "focus change during IME switch")
        TestAssert.Equal(fixture.output.deletes, 0, "focus change before delete is harmless")
        fixture := RefeedFixture()
        fixture.output.onLetter := (*) => fixture.contexts.identity := 2
        result := fixture.feature.ConvertSelection()
        TestAssert.Equal(result.reason, "SendingStopped", "focus loss stops further letters")
        TestAssert.Equal(fixture.output.letters, "n", "only first letter delivered to original target")
        TestAssert.Equal(fixture.feature.lastOriginal, "ni hao", "partial failure retains original")
        TestAssert.Equal(fixture.feature.busy, false, "partial failure releases busy flag")
        fixture := RefeedFixture()
        fixture.output.throwLetter := true
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "SendFailed", "send exception surfaced")
        TestAssert.Equal(fixture.feature.lastOriginal, "ni hao", "send exception retains original")
        TestAssert.Equal(fixture.clipboardDriver.value.image, "bitmap", "send exception restores clipboard")
        fixture := RefeedFixture()
        fixture.output.throwDelete := true
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "DeleteFailed", "delete exception surfaced")
        TestAssert.Equal(fixture.feature.lastOriginal, "ni hao", "uncertain deletion keeps recovery cache")
        fixture := RefeedFixture()
        fixture.ime.onPrepare := (*) => fixture.clipboardDriver.External("fresh copy")
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "ClipboardChanged", "external copy aborts revalidation")
        TestAssert.Equal(fixture.output.deletes, 0, "external copy prevents delete")
        TestAssert.Equal(fixture.clipboardDriver.value.text, "fresh copy", "external copy survives cleanup")
        fixture := RefeedFixture()
        fixture.keys.released := false
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "HotkeyReleaseTimeout", "modifier timeout")
        TestAssert.Equal(fixture.clipboardDriver.copies, 0, "held modifier sends no copy")
        fixture := RefeedFixture()
        fixture.enabled := false
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "Paused", "disabled feature ignores requests")
        fixture := RefeedFixture()
        fixture.feature.busy := true
        TestAssert.Equal(fixture.feature.ConvertSelection().reason, "Busy", "reentry rejected")
        TestAssert.Equal(fixture.feature.RecoverLast().reason, "Busy", "recover shares busy guard")
        fixture := RefeedFixture()
        TestAssert.Equal(fixture.feature.RecoverLast().reason, "NoCachedOriginal", "recover without cache")
        fixture := RefeedFixture()
        fixture.clipboardDriver.throwRestore := true
        result := fixture.feature.ConvertSelection()
        TestAssert.Equal(result.clipboardReason, "ClipboardRestoreFailed", "cleanup failure reported separately")
        TestAssert.Equal(fixture.feature.busy, false, "cleanup exception releases busy flag")
        TestAssert.Finish("refeed safety order, partial failures, clipboard cleanup and cross-window recovery")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
