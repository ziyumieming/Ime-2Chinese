#Requires AutoHotkey v2.0
#Include Defaults.ahk
#Include HotkeySpec.ahk
#Include ConfigStore.ahk

; Only editable preferences are patched into the latest valid configuration.
class SettingsModel {
    static Fields() => ["enableRefeed", "enableAutoSwitch", "startWithWindows", "refeedHotkey", "recoverHotkey",
        "sendIntervalMs", "maxRefeedLength", "copyTimeoutMs", "pollIntervalMs"]
    static Labels() => Map("enableRefeed", "重喂开关", "enableAutoSwitch", "自动切换开关",
        "startWithWindows", "开机自动启动",
        "refeedHotkey", "重喂快捷键", "recoverHotkey", "取回原文快捷键", "sendIntervalMs", "发送间隔",
        "maxRefeedLength", "长度上限", "copyTimeoutMs", "复制等待", "pollIntervalMs", "窗口检查间隔")
    static Clone(settings) => ConfigStore.Parse(ConfigStore.Serialize(settings))
    static Values(settings) {
        values := {}
        for name in this.Fields()
            values.%name% := settings.%name%
        values.refeedHotkey := this.DisplayHotkey(settings.refeedHotkey)
        values.recoverHotkey := this.DisplayHotkey(settings.recoverHotkey)
        return values
    }
    static DisplayHotkey(value) {
        parsed := HotkeySpec.Parse(value), text := ""
        for pair in [["^", "Ctrl"], ["!", "Alt"], ["+", "Shift"], ["#", "Win"]] {
            if InStr(parsed.value, pair[1])
                text .= pair[2] "+"
        }
        return text StrUpper(RegExReplace(parsed.value, "^[!+^#]+"))
    }
    static ReadHotkey(value) {
        value := Trim(value)
        if RegExMatch(value, "^[!+^#]")
            return HotkeySpec.Parse(value).value ; Existing INI notation remains accepted.
        parts := StrSplit(value, "+"), modifiers := "", names := Map("ctrl", "^", "alt", "!", "shift", "+", "win", "#")
        if parts.Length < 2
            throw ValueError("快捷键请写成 Alt+Z 或 Ctrl+Alt+F8，包含修饰键和一个按键。")
        loop parts.Length - 1 {
            name := StrLower(Trim(parts[A_Index]))
            if !names.Has(name)
                throw ValueError("快捷键修饰键支持 Ctrl、Alt、Shift、Win。")
            modifiers .= names[name]
        }
        return HotkeySpec.Parse(modifiers Trim(parts[parts.Length])).value
    }
    static Normalize(values) {
        candidate := Defaults.Create()
        for name in this.Fields() {
            if !values.HasOwnProp(name)
                throw ValueError("设置缺少必要字段。")
        }
        for name in ["enableRefeed", "enableAutoSwitch", "startWithWindows"] {
            if values.%name% != 0 && values.%name% != 1
                throw ValueError("功能开关须为启用或关闭。")
            candidate.%name% := Integer(values.%name%)
        }
        for name in ["refeedHotkey", "recoverHotkey"]
            candidate.%name% := this.ReadHotkey(values.%name%)
        for row in [["sendIntervalMs", 1, 1000], ["maxRefeedLength", 1, 500],
            ["copyTimeoutMs", 50, 5000], ["pollIntervalMs", 100, 5000]] {
            name := row[1], value := Trim(values.%name%)
            if !RegExMatch(value, "^\d+$") || value < row[2] || value > row[3]
                throw ValueError(this.Labels()[name] "须在 " row[2] "–" row[3] " 之间。")
            candidate.%name% := Integer(value)
        }
        return this.Clone(candidate)
    }
    static Merge(baseline, values, latest) {
        wanted := this.Normalize(values), candidate := this.Clone(latest), changes := 0
        for name in this.Fields() {
            if wanted.%name% = baseline.%name%
                continue
            if latest.%name% != baseline.%name% && latest.%name% != wanted.%name%
                throw ValueError(this.Labels()[name] "已在配置文件中修改，请关闭并重新打开设置后再保存。")
            candidate.%name% := wanted.%name%, changes += 1
        }
        return {settings: this.Clone(candidate), changes: changes}
    }
}
