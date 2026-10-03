#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\system\ClipboardService.ahk
#Include FakeInput.ahk
#Include TestAssert.ahk

RunTests()
RunTests() {
    try {
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        service.Begin()
        TestAssert.Throws(() => service.Begin(), "nested snapshot rejected")
        result := service.ReadSelection({}, 300)
        TestAssert.Equal(result.text, "ni hao", "selection captured")
        TestAssert.Equal(service.End().reason, "ClipboardRestored", "owned data restored")
        TestAssert.Equal(driver.value.image, "bitmap", "image format retained")
        TestAssert.Equal(driver.value.rich, "formatted", "rich text retained")
        TestAssert.Equal(service.active, false, "transaction released")
        TestAssert.Equal(service.snapshot, "", "backup released")
        TestAssert.Equal(service.End().reason, "NotStarted", "cleanup can repeat")
        service.Begin(), service.ReadSelection({}, 300)
        driver.External("fresh user copy")
        TestAssert.Equal(service.ReadSelection({}, 300).reason, "ClipboardChanged", "do not clear a newer clipboard")
        TestAssert.Equal(service.End().reason, "NewClipboardPreserved", "new user copy wins")
        TestAssert.Equal(driver.value.text, "fresh user copy", "new text preserved")
        TestAssert.Equal(driver.value.image, "new image", "new image preserved")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        driver.timeout := true
        service.Begin()
        TestAssert.Equal(service.ReadSelection({}, 300).reason, "CopyTimeout", "copy timeout")
        TestAssert.Equal(service.End().reason, "ClipboardRestored", "timeout restores empty owned clipboard")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        driver.ownerMatchesTarget := false
        service.Begin()
        TestAssert.Equal(service.ReadSelection({}, 300).reason, "UnexpectedClipboardOwner", "unexpected owner rejected")
        TestAssert.Equal(service.End().reason, "NewClipboardPreserved", "unexpected update not overwritten")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        driver.changeOnRead := true
        service.Begin()
        TestAssert.Equal(service.ReadSelection({}, 300).reason, "ClipboardChanged", "read race rejected")
        service.End()
        TestAssert.Equal(driver.value.text, "new while reading", "racing update preserved")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        driver.changeOnSnapshot := true
        TestAssert.Throws(() => service.Begin(), "snapshot race rejected")
        TestAssert.Equal(service.active, false, "snapshot race acquires no transaction")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        driver.sequenceNumber := 0
        TestAssert.Throws(() => service.Begin(), "missing sequence rejected before clearing")
        TestAssert.Equal(driver.value.text, "old clipboard", "no access preserves clipboard")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        driver.throwCopy := true
        service.Begin()
        TestAssert.Throws(() => service.ReadSelection({}, 300), "copy exception propagates to feature cleanup")
        service.End()
        TestAssert.Equal(driver.value.rich, "formatted", "copy exception still restores all formats")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        service.Begin(), service.ReadSelection({}, 300)
        driver.throwRestore := true
        TestAssert.Throws(() => service.End(), "restore failure surfaced")
        TestAssert.Equal(service.active, false, "restore failure releases lock")
        TestAssert.Equal(service.snapshot, "", "restore failure releases backup")
        driver := FakeClipboardDriver(), service := ClipboardService(driver)
        allowed := true
        driver.onClear := (*) => allowed := false
        service.Begin()
        TestAssert.Equal(service.ReadSelection({}, 300, () => allowed).reason, "TargetChanged", "focus rechecked after clipboard clear")
        TestAssert.Equal(driver.copies, 0, "no Ctrl+C after focus loss")
        TestAssert.Equal(service.End().reason, "ClipboardRestored", "cleared clipboard restored without sending copy")
        TestAssert.Finish("clipboard ownership, all-format restore, races, timeout and exceptions")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
