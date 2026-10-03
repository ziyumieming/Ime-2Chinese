#Requires AutoHotkey v2.0

class SelectionProbe {
    __New(driver := unset) => this.driver := IsSet(driver) ? driver : NativeSelection()
    Check(context) {
        try return this.driver.Read(context)
        catch
            return {state: "Unknown", token: 0}
    }
    IsCurrent(snapshot) {
        if !snapshot.token
            return true
        try return this.driver.IsCurrent(snapshot.token)
        catch
            return false
    }
}

class SelectionElement {
    __New(ptr) => this.ptr := ptr ; Own the COM reference returned by UIA.
    __Delete() => ObjRelease(this.ptr)
}

; Observe only: never SetFocus, Select, GetText, or send a copy command.
class NativeSelection {
    Factory() {
        if !this.HasOwnProp("automation") {
            factory := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}",
                "{34723AFF-0C9D-49D0-9896-7AB52DF8CD8A}") ; IUIAutomation2
            ComCall(59, factory, "Int", false) ; AutoSetFocus
            ComCall(61, factory, "UInt", 200) ; ConnectionTimeout
            ComCall(63, factory, "UInt", 200) ; TransactionTimeout
            this.automation := factory
        }
        return this.automation
    }

    Read(context) {
        if !context.focusKnown
            return {state: "Unknown", token: 0}
        className := WinGetClass("ahk_id " context.controlHwnd)
        if className = "Edit" || RegExMatch(className, "i)^RichEdit") {
            if WinGetStyle("ahk_id " context.controlHwnd) & 0x20 ; ES_PASSWORD
                return {state: "Empty", token: 0}
            return this.ReadEdit(context.controlHwnd)
        }
        element := 0
        ComCall(8, this.Factory(), "Ptr*", &element)
        return this.ReadElement(element, context.processId)
    }

    ReadEdit(hwnd) {
        first := Buffer(4, 0), last := Buffer(4, 0), result := 0
        sent := DllCall("user32\SendMessageTimeoutW", "Ptr", hwnd, "UInt", 0xB0,
            "Ptr", first, "Ptr", last, "UInt", 0x23, "UInt", 200, "Ptr*", &result, "Ptr")
        return {state: !sent ? "Unknown" : NumGet(first, 0, "UInt") = NumGet(last, 0, "UInt") ? "Empty" : "Selected", token: 0}
    }

    ReadElement(element, processId) {
        pattern := 0, ranges := 0, textRange := 0
        try {
            if !element
                return {state: "Unknown", token: 0}
            owner := 0, password := 0
            ComCall(20, element, "Int*", &owner)
            ComCall(35, element, "Int*", &password)
            if owner != processId
                return {state: "Unknown", token: 0}
            if password
                return {state: "Empty", token: 0}
            iid := Buffer(16, 0)
            DllCall("ole32\CLSIDFromString", "WStr", "{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}", "Ptr", iid)
            ComCall(14, element, "Int", 10014, "Ptr", iid, "Ptr*", &pattern) ; TextPattern
            ComCall(5, pattern, "Ptr*", &ranges)
            count := 0
            ComCall(3, ranges, "Int*", &count)
            if !count
                return {state: "Empty", token: 0}
            if count != 1
                return {state: "Unknown", token: 0}
            ComCall(4, ranges, "Int", 0, "Ptr*", &textRange)
            distance := 0
            ComCall(5, textRange, "Int", 0, "Ptr", textRange, "Int", 1, "Int*", &distance)
            token := SelectionElement(element), element := 0
            return {state: distance ? "Selected" : "Empty", token: token}
        } finally {
            for ptr in [textRange, ranges, pattern, element] {
                if ptr
                    ObjRelease(ptr)
            }
        }
    }

    IsCurrent(token) {
        current := 0
        try {
            ComCall(8, this.Factory(), "Ptr*", &current)
            same := 0
            if current
                ComCall(3, this.Factory(), "Ptr", token.ptr, "Ptr", current, "Int*", &same)
            return !!same
        } finally {
            if current
                ObjRelease(current)
        }
    }
}
