#Requires AutoHotkey v2.0

class SettingsWindow {
    __New(application) {
        this.application := application, this.baseline := SettingsModel.Clone(application.settings)
        this.window := Gui(, "Ime-2Chinese 设置"), this.controls := Map(), this.saving := false
        this.window.SetFont("s10", "Microsoft YaHei UI")
        this.window.MarginX := 18, this.window.MarginY := 14
        this.window.AddText("xm w460", application.InputAvailability())
        this.controls["enableRefeed"] := this.window.AddCheckbox("xm y+12", "启用重喂与取回原文")
        for row in [["refeedHotkey", "重喂快捷键", "例如 Alt+Z"],
            ["recoverHotkey", "取回原文快捷键", "例如 Alt+Shift+Z"],
            ["sendIntervalMs", "逐字发送间隔（毫秒）", "1–1000，默认 10"],
            ["maxRefeedLength", "选区长度上限（字符）", "1–500，默认 50"],
            ["copyTimeoutMs", "复制等待上限（毫秒）", "50–5000，默认 300"]] {
            this.window.AddText("xm y+12 w235", row[2])
            this.controls[row[1]] := this.window.AddEdit("x+8 yp-3 w210", "")
            this.window.AddText("xm y+3 w460 c666666", row[3])
        }
        this.window.AddText("xm y+12 w460", "使用当前中文输入法；其他语言跳过。窗口自动切换已暂停开发。")
        this.status := this.window.AddText("xm y+8 w460 r3", "")
        this.saveButton := this.window.AddButton("xm y+8 w130 Default", "保存并应用")
        this.saveButton.OnEvent("Click", (*) => this.Save())
        this.window.AddButton("x+8 w145", "读取当前配置").OnEvent("Click", (*) => this.ReloadFields())
        this.window.OnEvent("Close", (*) => this.window.Hide())
        this.window.OnEvent("Escape", (*) => this.window.Hide())
        this.Fill(this.baseline)
    }
    Show() => this.window.Show()
    Fill(settings) {
        values := SettingsModel.Values(settings)
        for name, control in this.controls
            control.Value := values.%name%
        this.baseline := SettingsModel.Clone(settings)
    }
    Values() {
        ; Frozen legacy preferences have no controls and must survive saving.
        values := SettingsModel.Values(this.baseline)
        for name, control in this.controls
            values.%name% := control.Value
        return values
    }
    Save() {
        if this.saving
            return
        this.saving := true, this.saveButton.Enabled := false
        try {
            result := this.application.SaveSettings(this.baseline, this.Values())
            this.status.Text := result.message
            if result.ok
                this.Fill(result.settings)
            return result
        } finally {
            this.saving := false, this.saveButton.Enabled := true
        }
    }
    ReloadFields() {
        try {
            this.Fill(this.application.store.Load(false))
            this.status.Text := "已读取文件；未保存的窗口改动已清除。点击保存并应用可应用这份配置。"
            return true
        } catch as err {
            this.status.Text := "读取失败，保留窗口内容：" err.Message
            return false
        }
    }
    Close() => this.window.Destroy()
}
