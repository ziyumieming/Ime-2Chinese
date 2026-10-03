#Requires AutoHotkey v2.0

class TrayMenu {
    __New(application) {
        this.application := application
        A_TrayMenu.Delete()
        A_TrayMenu.Add("��ͣ", (*) => application.TogglePause())
        A_TrayMenu.Add("������ι����δ���룩", (*) => application.ToggleFeature("enableRefeed"))
        A_TrayMenu.Add("�����Զ��л�����δ���룩", (*) => application.ToggleFeature("enableAutoSwitch"))
        A_TrayMenu.Add()
        A_TrayMenu.Add("������", (*) => application.OpenConfig())
        A_TrayMenu.Add("��������", (*) => application.Reload())
        A_TrayMenu.Add("������", (*) => MsgBox(application.logger.Recent(), "Ime-2Chinese"))
        A_TrayMenu.Add()
        A_TrayMenu.Add("�˳�", (*) => ExitApp())
        A_TrayMenu.Default := "������"
        this.Refresh()
    }
    Refresh() {
        application := this.application
        this.SetChecked("��ͣ", application.paused)
        this.SetChecked("������ι����δ���룩", application.settings.enableRefeed)
        this.SetChecked("�����Զ��л�����δ���룩", application.settings.enableAutoSwitch)
        A_IconTip := "Ime-2Chinese �� " (application.paused ? "����ͣ" : "���������̿��ã����빦�ܴ�����")
    }
    SetChecked(name, checked) {
        if checked
            A_TrayMenu.Check(name)
        else
            A_TrayMenu.Uncheck(name)
    }
}
