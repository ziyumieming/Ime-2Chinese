#Requires AutoHotkey v2.0

class TrayMenu {
    __New(application) {
        this.application := application
        A_TrayMenu.Delete()
        A_TrayMenu.Add("暂停", (*) => application.TogglePause())
        A_TrayMenu.Add("启用重喂（尚未接入）", (*) => application.ToggleFeature("enableRefeed"))
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
        this.SetChecked("启用重喂（尚未接入）", application.settings.enableRefeed)
        this.SetChecked("启用自动切换（尚未接入）", application.settings.enableAutoSwitch)
        A_IconTip := "Ime-2Chinese — " (application.paused ? "已暂停" : "配置与托盘可用；输入功能待接入")
    }
    SetChecked(name, checked) {
        if checked
            A_TrayMenu.Check(name)
        else
            A_TrayMenu.Uncheck(name)
    }
}
