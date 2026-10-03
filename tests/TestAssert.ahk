#Requires AutoHotkey v2.0

class TestAssert {
    static count := 0
    static Equal(actual, expected, label) {
        if actual != expected
            throw Error(label ": expected " expected ", got " actual)
        this.count += 1
    }
    static Throws(callback, label) {
        failed := false
        try callback.Call()
        catch
            failed := true
        this.Equal(failed, true, label)
    }
    static Finish(label) => FileAppend("PASS " this.count " assertions: " label "`n", "*")
}
