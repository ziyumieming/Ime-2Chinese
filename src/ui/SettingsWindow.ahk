#Requires AutoHotkey v2.0

class SettingsWindow {
    __New(application) {
        this.application := application, this.baseline := SettingsModel.Clone(application.settings)
        this.window := Gui(, "Ime-2Chinese 设置"), this.controls := Map(), this.saving := false
        this.window.SetFont("s10", "Microsoft YaHei UI")
        this.window.MarginX := 18, this.window.MarginY := 14
        this.window.AddText("xm w460", application.InputAvailability())
        this.controls["enableRefeed"] := this.window.AddCheckbox("xm y+12", "启用重喂与取回原文")
        this.controls["startWithWindows"] := this.window.AddCheckbox("xm y+8", "开机自动启动（登录当前用户后）")
        this.recordButtons := Map(), this.recordingField := ""
        for row in [["refeedHotkey", "重喂快捷键", "例如 Alt+Z"],
            ["recoverHotkey", "取回原文快捷键", "例如 Alt+Shift+Z"],
            ["sendIntervalMs", "逐字发送间隔（毫秒）", "1–1000，默认 10"],
            ["maxRefeedLength", "选区长度上限（字符）", "1–500，默认 50"],
            ["copyTimeoutMs", "复制等待上限（毫秒）", "50–5000，默认 300"]] {
            this.window.AddText("xm y+12 w235", row[2])
            isHotkey := InStr(row[1], "Hotkey")
            this.controls[row[1]] := this.window.AddEdit("x+8 yp-3 " (isHotkey ? "w125 ReadOnly" : "w210"), "")
            if isHotkey {
                button := this.window.AddButton("x+5 yp w80", "录制")
                this.recordButtons[row[1]] := button
                button.OnEvent("Click", ObjBindMethod(this, "RecordKey", row[1]))
            }
            this.window.AddText("xm y+3 w460 c666666", row[3])
        }
        this.window.AddText("xm y+12 w460", "使用当前中文输入法；其他语言跳过。窗口自动切换已暂停开发。")
        this.status := this.window.AddText("xm y+8 w460 r3", "")
        this.saveButton := this.window.AddButton("xm y+8 w130 Default", "保存并应用")
        this.saveButton.OnEvent("Click", (*) => this.Save())
        this.window.OnEvent("Close", (*) => this.Hide())
        this.window.OnEvent("Escape", (*) => this.Hide())
        this.activationHandler := ObjBindMethod(this, "Activation")
        OnMessage(0x6, this.activationHandler)
        this.Fill(this.baseline)
    }
    Show() {
        if !DllCall("IsWindowVisible", "Ptr", this.window.Hwnd) {
            try this.Fill(this.application.store.Load(false))
            catch as err
                this.status.Text := "读取设置失败：" err.Message
        }
        this.window.Show()
    }
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
        if this.saving || this.recordingField != ""
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
    RecordKey(name, *) {
        if this.recordingField != "" {
            this.recorder.Cancel()
            return
        }
        if !this.application.BeginHotkeyCapture() {
            this.status.Text := "正在处理输入或配置，请稍后录制。"
            return
        }
        this.recordingField := name, this.saveButton.Enabled := false
        this.recordButtons[name].Text := "取消"
        this.status.Text := "请按下组合键，全部松开后完成；Esc 或离开窗口取消。"
        try {
            this.recorder := HotkeyRecorder(this.window.Hwnd, ObjBindMethod(this, "KeyCandidate"),
                ObjBindMethod(this, "KeyComplete"), ObjBindMethod(this, "KeyCancel"))
            this.recorder.Start()
        } catch as err {
            if this.HasOwnProp("recorder")
                try this.recorder.Stop()
            this.EndRecording()
            this.status.Text := "无法开始录制：" err.Message
        }
    }
    KeyCandidate(value, error := "") {
        this.status.Text := value != "" ? "已捕获 " SettingsModel.DisplayHotkey(value) "，请松开全部按键。" : error " 请重新按组合键。"
    }
    KeyComplete(value) {
        if this.recordingField = ""
            return
        this.controls[this.recordingField].Value := SettingsModel.DisplayHotkey(value)
        this.EndRecording()
        this.status.Text := "快捷键已录制；点击保存并应用后生效。"
    }
    KeyCancel() {
        this.EndRecording()
        this.status.Text := "已取消录制，保留原快捷键。"
    }
    EndRecording() {
        if this.recordingField = ""
            return
        this.recordButtons[this.recordingField].Text := "录制"
        this.recordingField := "", this.saveButton.Enabled := true
        try this.application.EndHotkeyCapture()
        catch as err
            this.status.Text := "恢复快捷键失败，请重启程序：" err.Message
    }
    Activation(wParam, lParam, message, hwnd) {
        if hwnd = this.window.Hwnd && (wParam & 0xFFFF) = 0 && this.recordingField != ""
            this.recorder.Cancel()
    }
    Hide() {
        if this.recordingField != ""
            this.recorder.Cancel()
        this.window.Hide()
    }
    Close() {
        this.Hide()
        OnMessage(0x6, this.activationHandler, 0)
        this.window.Destroy()
    }
}
