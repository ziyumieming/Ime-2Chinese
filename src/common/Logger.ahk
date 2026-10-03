#Requires AutoHotkey v2.0

; Accept only code identifiers, never input content, paths or window titles.
class Logger {
    __New(limit := 30) {
        this.limit := limit, this.entries := []
    }
    Record(event, result) {
        if !RegExMatch(event, "^[A-Za-z0-9_]+$") || !RegExMatch(result, "^[A-Za-z0-9_]+$")
            throw ValueError("Diagnostic identifiers only")
        this.entries.Push(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " event " " result)
        while this.entries.Length > this.limit
            this.entries.RemoveAt(1)
    }
    Recent() {
        text := ""
        for entry in this.entries
            text .= entry "`n"
        return text != "" ? RTrim(text, "`n") : "������ϡ�"
    }
}
