#Requires AutoHotkey v2.0

class HotkeySpec {
    static Parse(value) {
        if !RegExMatch(Trim(value), "^([!+^#]+)([A-Za-z0-9]+)$", &match)
            throw ValueError("热键须包含修饰符及单个按键，例如 !z、^!F8。")
        modifiers := ""
        for symbol in StrSplit("^!+#") {
            count := StrLen(match[1]) - StrLen(StrReplace(match[1], symbol))
            if count > 1
                throw ValueError("热键的修饰符不能重复。")
            if count
                modifiers .= symbol
        }
        key := StrLower(match[2]), vk := GetKeyVK(key), sc := GetKeySC(key)
        if (!vk && !sc) || RegExMatch(key, "i)^(l|r)?(ctrl|control|alt|shift|win)$")
            throw ValueError("热键按键无效。")
        return {value: modifiers key, identity: modifiers (vk ? "vk" vk : "sc" sc)}
    }
}
