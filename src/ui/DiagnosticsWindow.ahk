#Requires AutoHotkey v2.0

class DiagnosticsWindow {
    __New(application) {
        this.application := application
        this.visible := false, this.pending := false, this.subscription := 0, this.closed := false
        this.message := 0x8051
        this.messageHandler := ObjBindMethod(this, "Dispatch")
        OnMessage(this.message, this.messageHandler)
        this.window := Gui("+Resize +MinSize480x300", "Ime-2Chinese 最近诊断")
        this.window.SetFont("s10", "Microsoft YaHei UI")
        this.text := this.window.AddEdit("xm ym w620 h310 ReadOnly -Wrap", "")
        this.refreshButton := this.window.AddButton("xm y+12 w100", "刷新")
        this.refreshButton.OnEvent("Click", (*) => this.Refresh())
        this.clearButton := this.window.AddButton("x+8 w120", "清空记录")
        this.clearButton.OnEvent("Click", (*) => this.Clear())
        this.exportButton := this.window.AddButton("x+8 w110", "导出文件")
        this.exportButton.OnEvent("Click", (*) => this.ExportInteractive())
        this.window.OnEvent("Close", (*) => this.Hide())
        this.window.OnEvent("Escape", (*) => this.Hide())
        this.window.OnEvent("Size", (window, state, width, height) => this.Resize(state, width, height))
        this.Refresh()
    }
    Show() {
        this.Watch()
        this.Refresh()
        this.window.Show()
    }
    Watch() {
        this.visible := true
        if !this.subscription
            this.subscription := this.application.logger.Subscribe(ObjBindMethod(this, "Changed"))
    }
    Changed() {
        if !this.closed && this.visible && !this.pending {
            this.pending := true
            if !DllCall("user32\PostMessageW", "Ptr", this.window.Hwnd, "UInt", this.message, "Ptr", 0, "Ptr", 0)
                this.pending := false
        }
    }
    Dispatch(wParam, lParam, message, hwnd) {
        if this.closed || hwnd != this.window.Hwnd
            return
        this.pending := false
        if this.visible
            this.Refresh()
        return 0
    }
    Hide() {
        this.visible := false
        this.application.logger.Unsubscribe(this.subscription)
        this.subscription := 0, this.pending := false
        this.window.Hide()
    }
    Export(path := unset) {
        snapshot := this.application.DiagnosticSummary()
        if !IsSet(path)
            path := FileSelect("S16", "Ime-2Chinese-diagnostics-" FormatTime(, "yyyyMMdd-HHmmss") ".txt", "导出诊断快照", "文本文件 (*.txt)")
        if path = ""
            return false
        outputFile := FileOpen(path, "w", "UTF-8-RAW")
        if !outputFile
            throw Error("无法导出诊断文件。")
        try outputFile.Write(snapshot)
        finally outputFile.Close()
        return true
    }
    ExportInteractive() {
        try this.Export()
        catch as err
            MsgBox(err.Message, "诊断导出失败")
    }
    Refresh() => this.text.Value := this.application.DiagnosticSummary()
    Clear() {
        this.application.logger.Clear()
        this.Refresh()
    }
    Resize(state, width, height) {
        if state != -1 {
            this.text.Move(, , Max(200, width - 28), Max(120, height - 70))
            this.refreshButton.Move(, Max(140, height - 44))
            this.clearButton.Move(, Max(140, height - 44))
            this.exportButton.Move(, Max(140, height - 44))
        }
    }
    Close() {
        if this.closed
            return
        this.Hide(), this.closed := true
        OnMessage(this.message, this.messageHandler, 0)
        this.window.Destroy()
    }
}
