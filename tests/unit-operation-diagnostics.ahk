#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include FakeInput.ahk
#Include TestAssert.ahk
RunTests()
RunTests() {
try {
    history := Logger(2), updates := 0
    token := history.Subscribe(() => updates += 1)
    bad := history.Subscribe(() => ThrowCallback())
    operation := history.Begin("Refeed")
    history.Stage(operation, "CaptureTarget", {title: "full private title", hwnd: 123, hkl: 2052})
    history.Stage(operation, "CopySelection", {text: "Ni hao`n", sequence: 21, ownerMatches: true})
    history.Stage(operation, "PrepareIme", {beforeStatus: {openStatus: 0, conversionMode: 0}, status: {openStatus: 1, conversionMode: 1025}})
    history.Finish(operation, {reason: "CandidatesReady", changed: true, sent: 5, cacheAvailable: true})
    TestAssert.Equal(InStr(history.Recent(), "full private title") > 0, true, "full title retained")
    TestAssert.Equal(InStr(history.Recent(), "selectedText=Ni hao\n") > 0, true, "authorized selected text retained")
    TestAssert.Equal(InStr(history.Recent(), "beforeStatus.openStatus=0") > 0, true, "raw before IME status")
    TestAssert.Equal(InStr(history.Recent(), "status.conversionMode=1025") > 0, true, "raw after IME status")
    TestAssert.Equal(updates, 5, "observer callbacks without timer and isolated subscriber error")
    history.Unsubscribe(token), history.Stage(operation, "More", {})
    TestAssert.Equal(updates, 5, "unsubscribed callback not invoked")
    history.Unsubscribe(bad)
    history.Stage(operation, "Large", {text: StrReplace(Format("{:5000}", "x"), " ", "x")})
    TestAssert.Equal(InStr(history.Recent(), "原长度 5000") > 0, true, "text truncation visible")
    loop 70
        history.Stage(operation, "Bounded", {})
    TestAssert.Equal(operation.steps.Length, 64, "steps bounded per operation")
    TestAssert.Equal(operation.dropped > 0, true, "step omission counted")
    history.Begin("Recover"), history.Begin("Refeed")
    TestAssert.Equal(history.entries.Length, 2, "whole operations evicted")
    driver := FakeClipboardDriver(), output := FakeOutput()
    feature := RefeedFeature(() => Defaults.Create(), {contexts: FakeContext(), keys: FakeKeys(),
        clipboard: ClipboardService(driver), sender: TextSender(output), ime: PreparedIme(),
        editable: FakeEditable(), selection: FakeSelection(), logger: history}, () => true)
    output.onLetter := (*) => output.throwLetter := true
    result := feature.ConvertSelection()
    TestAssert.Equal(result.sent, 1, "partial sender exception reports delivered count")
    TestAssert.Equal(result.cacheAvailable, true, "failure retains cache")
    TestAssert.Equal(InStr(history.Recent(), "error=letter failure") > 0, true, "exception and stage observable")
    TestAssert.Equal(InStr(history.Recent(), "ClipboardRestored") > 0, true, "cleanup recorded after failure")
    application := App(), application.logger := history
    panel := DiagnosticsWindow(application), panel.window.Show("Hide"), panel.Watch()
    history.Record("Refeed", "CopyTimeout")
    TestAssert.Equal(panel.pending, true, "callbacks enqueue refresh")
    Sleep(30)
    TestAssert.Equal(InStr(panel.text.Value, "复制选区超时") > 0, true, "native message refreshes visible window")
    panel.Hide(), history.Record("Recover", "OriginalRecovered")
    TestAssert.Equal(panel.subscription, 0, "hidden panel unsubscribed")
    path := A_ScriptDir "\..\.task-tmp\diagnostics-" DllCall("GetCurrentProcessId", "UInt") ".txt"
    try {
        TestAssert.Equal(panel.Export(path), true, "snapshot exports")
        TestAssert.Equal(FileRead(path, "UTF-8"), application.DiagnosticSummary(), "UTF-8 export contains snapshot")
    } finally {
        if FileExist(path)
            FileDelete(path)
        panel.Close()
    }
    TestAssert.Equal(history.listeners.Count, 0, "close removes observers")
    history := Logger()
    loop 2 {
        operation := history.Begin("Refeed")
        history.Stage(operation, "EditableCheck", {reason: "ReadOnlyTarget"})
        history.Finish(operation, {reason: "ReadOnlyTarget", failedStage: "EditableCheck", operationId: operation.id})
    }
    TestAssert.Equal(history.entries.Length, 1, "identical blocked operations merge as whole groups")
    TestAssert.Equal(history.entries[1].count, 2, "repeat count retained with first and last operation IDs")
    TestAssert.Finish("operation diagnostics, partial failure, bounds, callback refresh and UTF-8 export")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
    ExitApp(1)
}
}
ThrowCallback() => ThrowHelper()
ThrowHelper() {
    throw Error("bad observer")
}
