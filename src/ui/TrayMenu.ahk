#Requires AutoHotkey v2.0

class TrayMenu {
    __New(application) {
        this.application := application
        A_TrayMenu.Delete()
        A_TrayMenu.Add("暂停", (*) => application.TogglePause())
        A_TrayMenu.Add()
        A_TrayMenu.Add("设置", (*) => application.OpenSettings())
        A_TrayMenu.Add("最近诊断", (*) => application.OpenDiagnostics())
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "设置"
        this.Refresh()
    }
    Refresh() {
        application := this.application
        this.SetChecked("暂停", application.paused)
        A_IconTip := "Ime-2Chinese — " (application.paused ? "已暂停"
            : application.HasOwnProp("auto") ? "历史全功能 MVP（自动切换已冻结）"
            : application.testMode ? "重喂 MVP 测试"
            : application.HasOwnProp("refeed") ? "重喂与取回原文" : "设置与托盘")
    }
    SetChecked(name, checked) {
        if checked
            A_TrayMenu.Check(name)
        else
            A_TrayMenu.Uncheck(name)
    }
}
