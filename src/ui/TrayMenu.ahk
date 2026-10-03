#Requires AutoHotkey v2.0

class TrayMenu {
    __New(application) {
        this.application := application
        this.refeedLabel := application.testMode ? "启用重喂（测试版）" : "启用重喂（需启动测试版）"
        A_TrayMenu.Delete()
        A_TrayMenu.Add("暂停", (*) => application.TogglePause())
        A_TrayMenu.Add(this.refeedLabel, (*) => application.ToggleFeature("enableRefeed"))
        A_TrayMenu.Add("启用自动切换（尚未接入）", (*) => application.ToggleFeature("enableAutoSwitch"))
        A_TrayMenu.Add()
        A_TrayMenu.Add("打开配置", (*) => application.OpenConfig())
        A_TrayMenu.Add("重载配置", (*) => application.Reload())
        A_TrayMenu.Add("最近诊断", (*) => MsgBox(application.logger.Recent(), "Ime-2Chinese"))
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "打开配置"
        this.Refresh()
    }
    Refresh() {
        application := this.application
        this.SetChecked("暂停", application.paused)
        this.SetChecked(this.refeedLabel, application.settings.enableRefeed)
        this.SetChecked("启用自动切换（尚未接入）", application.settings.enableAutoSwitch)
        A_IconTip := "Ime-2Chinese — " (application.paused ? "已暂停"
            : application.testMode ? "重喂 MVP 测试" : "配置与托盘可用；重喂需测试入口")
    }
    SetChecked(name, checked) {
        if checked
            A_TrayMenu.Check(name)
        else
            A_TrayMenu.Uncheck(name)
    }
}
