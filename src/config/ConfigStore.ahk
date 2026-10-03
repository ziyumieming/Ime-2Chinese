#Requires AutoHotkey v2.0

class ConfigStore {
    __New(path := "") {
        this.path := path != "" ? path : A_AppData "\ImeAssist\settings.ini"
    }

    Load(createIfMissing := true) {
        if !FileExist(this.path) {
            if !createIfMissing
                throw Error("配置文件不存在。")
            this.Save(Defaults.Create())
        }
        return ConfigStore.Parse(FileRead(this.path, "UTF-8"))
    }

    Save(settings) {
        text := ConfigStore.Serialize(settings)
        ConfigStore.Parse(text) ; Validate before touching the old outputFile.
        SplitPath(this.path, , &directory)
        if directory != ""
            DirCreate(directory)
        temporary := this.path ".tmp-" DllCall("GetCurrentProcessId", "UInt")
        try {
            outputFile := FileOpen(temporary, "w", "UTF-8-RAW")
            if !outputFile
                throw Error("不能写入配置文件。")
            try outputFile.Write(text)
            finally outputFile.Close()
            if FileRead(temporary, "UTF-8") != text
                throw Error("配置写入不完整，原文件保持不变。")
            FileMove(temporary, this.path, true)
        } finally {
            if FileExist(temporary)
                FileDelete(temporary)
        }
    }

    static Parse(text) {
        settings := Defaults.Create(), sections := Map(), current := ""
        sections.CaseSense := "Off"
        for lineNumber, raw in StrSplit(StrReplace(text, "`r"), "`n") {
            line := Trim(raw, " `t" Chr(0xFEFF))
            if line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#"
                continue
            if RegExMatch(line, "^\[([^\]]+)\]$", &match) {
                current := Trim(match[1])
                if sections.Has(current)
                    throw ValueError("重复的配置节，第 " lineNumber " 行。")
                fields := Map()
                fields.CaseSense := "Off"
                sections[current] := fields
                continue
            }
            equal := InStr(line, "=")
            if current = "" || !equal
                throw ValueError("配置格式无效，第 " lineNumber " 行。")
            key := Trim(SubStr(line, 1, equal - 1))
            if key = "" || sections[current].Has(key)
                throw ValueError("空键名或重复的配置键，第 " lineNumber " 行。")
            sections[current][key] := Trim(SubStr(line, equal + 1))
        }
        for section, fields in sections {
            switch StrLower(section) {
                case "general":
                    ConfigStore.CheckKeys(fields, ["EnableRefeed", "EnableAutoSwitch", "RefeedHotkey", "RecoverHotkey", "SendIntervalMs", "MaxRefeedLength", "CopyTimeoutMs"])
                    settings.enableRefeed := ConfigStore.Number(fields, "EnableRefeed", 1, 0, 1)
                    settings.enableAutoSwitch := ConfigStore.Number(fields, "EnableAutoSwitch", 1, 0, 1)
                    settings.refeedHotkey := ConfigStore.Value(fields, "RefeedHotkey", "!z")
                    settings.recoverHotkey := ConfigStore.Value(fields, "RecoverHotkey", "!+z")
                    settings.sendIntervalMs := ConfigStore.Number(fields, "SendIntervalMs", 10, 1, 1000)
                    settings.maxRefeedLength := ConfigStore.Number(fields, "MaxRefeedLength", 50, 1, 500)
                    settings.copyTimeoutMs := ConfigStore.Number(fields, "CopyTimeoutMs", 300, 50, 5000)
                case "ime":
                    ConfigStore.CheckKeys(fields, ["RefeedTarget"])
                    settings.refeedTarget := ConfigStore.Value(fields, "RefeedTarget", "SogouPinyin")
                    if settings.refeedTarget != "SogouPinyin" && settings.refeedTarget != "MicrosoftPinyin"
                        throw ValueError("RefeedTarget 仅支持 SogouPinyin 或 MicrosoftPinyin。")
                case "autoswitch":
                    ConfigStore.CheckKeys(fields, ["PollIntervalMs", "DefaultAction"])
                    settings.pollIntervalMs := ConfigStore.Number(fields, "PollIntervalMs", 300, 100, 5000)
                    settings.defaultAction := ConfigStore.Value(fields, "DefaultAction", "Ignore")
                    if settings.defaultAction != "Ignore"
                        throw ValueError("DefaultAction 必须为 Ignore；无匹配时保持原状态。")
                default:
                    if !RegExMatch(section, "i)^Rule\.([A-Za-z0-9_-]+)$", &ruleMatch)
                        throw ValueError("未知配置节：" section)
                    ConfigStore.CheckKeys(fields, ["Process", "TitleContains", "Mode"])
                    process := ConfigStore.Value(fields, "Process", ""), mode := ConfigStore.Value(fields, "Mode", "")
                    if !RegExMatch(process, "i)^[^\\/:*?" Chr(34) "<>|\s]+\.exe$")
                        throw ValueError("规则须指定不含路径的进程名，例如 notepad.exe。")
                    if mode != "Chinese" && mode != "English" && mode != "Ignore"
                        throw ValueError("规则 Mode 须为 Chinese、English 或 Ignore。")
                    settings.rules.Push({id: ruleMatch[1], process: process,
                        titleContains: ConfigStore.Value(fields, "TitleContains", ""), mode: mode})
            }
        }
        first := HotkeySpec.Parse(settings.refeedHotkey), second := HotkeySpec.Parse(settings.recoverHotkey)
        if first.identity = second.identity
            throw ValueError("重喂与取回原文的热键不能相同。")
        settings.refeedHotkey := first.value, settings.recoverHotkey := second.value
        return settings
    }

    static Value(fields, key, fallback) => fields.Has(key) ? fields[key] : fallback

    static Number(fields, key, fallback, minimum, maximum) {
        value := ConfigStore.Value(fields, key, fallback)
        if !RegExMatch(value, "^\d+$") || value < minimum || value > maximum
            throw ValueError(key " 的值须在 " minimum "–" maximum " 之间。")
        return Integer(value)
    }

    static CheckKeys(fields, allowed) {
        names := Map()
        names.CaseSense := "Off"
        for key in allowed
            names[key] := true
        for key in fields {
            if !names.Has(key)
                throw ValueError("未知配置键：" key)
        }
    }

    static Serialize(settings) {
        text := "; Ime-2Chinese configuration. Rules are matched in outputFile order.`n"
            . "[General]`nEnableRefeed=" (!!settings.enableRefeed) "`nEnableAutoSwitch=" (!!settings.enableAutoSwitch)
            . "`nRefeedHotkey=" settings.refeedHotkey "`nRecoverHotkey=" settings.recoverHotkey
            . "`nSendIntervalMs=" settings.sendIntervalMs "`nMaxRefeedLength=" settings.maxRefeedLength
            . "`nCopyTimeoutMs=" settings.copyTimeoutMs "`n`n[Ime]`nRefeedTarget=" settings.refeedTarget
            . "`n`n[AutoSwitch]`nPollIntervalMs=" settings.pollIntervalMs "`nDefaultAction=" settings.defaultAction "`n"
        for rule in settings.rules
            text .= "`n[Rule." rule.id "]`nProcess=" rule.process "`nTitleContains=" rule.titleContains "`nMode=" rule.mode "`n"
        return text
    }
}
