#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\App.ahk
#Include TestAssert.ahk

class NoticeCollector {
    __New() => (this.items := [], this.failNext := false)
    Show(message) {
        if this.failNext {
            this.failNext := false
            throw Error("notification failed")
        }
        this.items.Push(message)
    }
}
RunTests()
RunTests() {
try {
    history := Logger(2, () => "2026-10-04 12:00:00")
    history.Record("Refeed", "CopyTimeout"), history.Record("Refeed", "CopyTimeout")
    TestAssert.Equal(history.entries.Length, 1, "consecutive duplicate aggregated")
    TestAssert.Equal(history.entries[1].count, 2, "repeat count retained")
    TestAssert.Equal(InStr(history.Recent(), "复制选区超时") > 0, true, "readable result")
    TestAssert.Equal(InStr(history.Recent(), "连续 2 次") > 0, true, "readable repeated count")
    history.Record("Startup", "Ready"), history.Record("Pause", "Paused")
    TestAssert.Equal(history.entries.Length, 2, "capacity bounded")
    TestAssert.Equal(InStr(history.Recent(), "复制选区超时"), 0, "old record evicted")
    TestAssert.Throws(() => history.Record("private text", "Ready"), "raw event rejected")
    TestAssert.Throws(() => history.Record("Refeed", "Private title"), "raw result rejected")
    history.Clear()
    TestAssert.Equal(history.Recent(), "暂无诊断。", "clear memory records")
    history.Record("FutureEvent", "FutureResult")
    TestAssert.Equal(InStr(history.Recent(), "FutureResult") > 0, true, "unknown identifiers retained")
    collector := NoticeCollector(), tick := 0, notice := Notify(collector, () => tick)
    notice.Show("A"), tick := 100, notice.Show("B"), tick := 200, notice.Show("A")
    TestAssert.Equal(collector.items.Length, 2, "interleaved duplicate suppressed")
    tick := 2999, notice.Show("A")
    TestAssert.Equal(collector.items.Length, 2, "cooldown not extended by suppressed calls")
    tick := 3000, notice.Show("A")
    TestAssert.Equal(collector.items.Length, 3, "message allowed at cooldown boundary")
    loop 25 {
        tick += 10
        notice.Show("Message" A_Index)
    }
    TestAssert.Equal(notice.recent.Count, 20, "dedup memory bounded")
    collector.failNext := true
    TestAssert.Throws(() => notice.Show("Retry"), "delivery failure reported")
    notice.Show("Retry")
    TestAssert.Equal(collector.items[collector.items.Length], "Retry", "failed delivery not incorrectly suppressed")
    application := App()
    TestAssert.Equal(InStr(application.DiagnosticSummary(), "输入功能需显式") > 0, true, "entry availability explained")
    application.logger.Record("Refeed", "NoSelection")
    TestAssert.Equal(InStr(application.DiagnosticSummary(), "无选区，已跳过") > 0, true, "summary contains readable history")
    TestAssert.Equal(application.logger.entries.Length, 1, "view does not create log records")
    TestAssert.Finish("readable bounded diagnostics and deduplicated notifications")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
    ExitApp(1)
}
}
