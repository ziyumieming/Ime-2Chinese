#Requires AutoHotkey v2.0

class HotkeySpec {
    static Parse(value) {
        if !RegExMatch(Trim(value), "^([!+^#]+)([A-Za-z0-9]+)$", &match)
            throw ValueError("�ȼ���������η����������������� !z��^!F8��")
        modifiers := ""
        for symbol in StrSplit("^!+#") {
            count := StrLen(match[1]) - StrLen(StrReplace(match[1], symbol))
            if count > 1
                throw ValueError("�ȼ������η������ظ���")
            if count
                modifiers .= symbol
        }
        key := StrLower(match[2]), vk := GetKeyVK(key), sc := GetKeySC(key)
        if (!vk && !sc) || RegExMatch(key, "i)^(l|r)?(ctrl|control|alt|shift|win)$")
            throw ValueError("�ȼ�������Ч��")
        return {value: modifiers key, identity: modifiers (vk ? "vk" vk : "sc" sc)}
    }
}
