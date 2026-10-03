#Requires AutoHotkey v2.0

class TextRules {
    static Validate(original, maximum := 50) {
        if original = ""
            return {ok: false, reason: "NoSelection"}
        if StrLen(original) > maximum
            return {ok: false, reason: "TextTooLong"}
        if !RegExMatch(original, "^[a-zA-Z\s]+$")
            return {ok: false, reason: "InvalidText"}
        letters := RegExReplace(original, "\s", "")
        if letters = ""
            return {ok: false, reason: "WhitespaceOnly"}
        return {ok: true, reason: "Valid", original: original, letters: letters}
    }
}
