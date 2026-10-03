#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include ..\src\common\TextRules.ahk
#Include TestAssert.ahk

RunTests()
RunTests() {
    try {
        valid := TextRules.Validate("Ni hao`r`nMA`t")
        TestAssert.Equal(valid.ok, true, "letters and whitespace accepted")
        TestAssert.Equal(valid.original, "Ni hao`r`nMA`t", "original retained verbatim")
        TestAssert.Equal(valid.letters, "NihaoMA", "whitespace stripped, case preserved")
        fifty := "a" StrReplace(Format("{:049}", 0), "0", " ")
        TestAssert.Equal(StrLen(fifty), 50, "length fixture")
        TestAssert.Equal(TextRules.Validate(fifty).ok, true, "50 including whitespace accepted")
        TestAssert.Equal(TextRules.Validate(fifty " ").reason, "TextTooLong", "51 rejected before stripping")
        TestAssert.Equal(TextRules.Validate(" ").reason, "WhitespaceOnly", "spaces rejected")
        TestAssert.Equal(TextRules.Validate("`r`n`t").reason, "WhitespaceOnly", "other whitespace rejected")
        TestAssert.Equal(TextRules.Validate("").reason, "NoSelection", "empty rejected")
        for invalid in ["你好", "ni1hao", "ni-hao", "ni.hao", "ni_hao", "é", "Ａ", "a😀"]
            TestAssert.Equal(TextRules.Validate(invalid).reason, "InvalidText", "non-ASCII-letter rejected")
        TestAssert.Equal(TextRules.Validate("abc", 2).reason, "TextTooLong", "configured maximum used")
        TestAssert.Finish("demo text boundaries, whitespace and original/case preservation")
        ExitApp(0)
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
}
