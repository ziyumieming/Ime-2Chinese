#Requires AutoHotkey v2.0

class DiagnosticsWindow {
    __New(application) {
        this.application := application
        this.window := Gui("+Resize +MinSize480x300", "Ime-2Chinese 最近诊断")
        this.window.SetFont("s10", "Microsoft YaHei UI")
        this.text := this.window.AddEdit("xm ym w620 h310 ReadOnly -Wrap", "")
        this.refreshButton := this.window.AddButton("xm y+12 w100", "刷新")
        this.refreshButton.OnEvent("Click", (*) => this.Refresh())
        this.clearButton := this.window.AddButton("x+8 w120", "清空记录")
        this.clearButton.OnEvent("Click", (*) => this.Clear())
        this.window.OnEvent("Close", (*) => this.window.Hide())
        this.window.OnEvent("Escape", (*) => this.window.Hide())
        this.window.OnEvent("Size", (window, state, width, height) => this.Resize(state, width, height))
        this.Refresh()
    }
    Show() {
        this.Refresh()
        this.window.Show()
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
        }
    }
    Close() => this.window.Destroy()
}
