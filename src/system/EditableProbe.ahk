#Requires AutoHotkey v2.0
#Include SelectionProbe.ahk

; Read metadata only. Never read field contents or move the user's focus.
class EditableProbe {
    __New(driver := unset) => this.driver := IsSet(driver) ? driver : NativeEditable()
    Check(context) {
        try return this.driver.Read(context)
        catch as err
            return {state: "Unknown", reason: "EditableUnknown", token: 0, error: err.Message, line: err.Line, file: err.File}
    }
    IsCurrent(snapshot, context) {
        try return this.driver.IsCurrent(snapshot, context)
        catch
            return false
    }
}

class NativeEditable extends NativeSelection {
    Read(context) {
        if !context.focusKnown
            return this.Result("Unknown", "EditableUnknown")
        if RegExMatch(context.className, "i)^(ConsoleWindowClass|CASCADIA_HOSTING_WINDOW_CLASS|PseudoConsoleWindow)$")
            return this.Result("Unsupported", "TerminalUnsupported")
        className := WinGetClass("ahk_id " context.controlHwnd)
        if className = "Edit" || RegExMatch(className, "i)^RichEdit")
            return this.ReadNative(context.controlHwnd)
        element := 0
        ComCall(8, this.Factory(), "Ptr*", &element)
        return this.ReadElement(element, context.processId)
    }
    Result(state, reason, source := "None", token := 0) => {state: state, reason: reason, source: source, token: token}
    ReadNative(hwnd) {
        style := WinGetStyle("ahk_id " hwnd)
        enabled := !!DllCall("user32\IsWindowEnabled", "Ptr", hwnd, "Int")
        result := this.Decide(enabled, !!(style & 0x20), !!(style & 0x800), 50004)
        result.source := "NativeEdit", result.controlHwnd := hwnd, result.token := 0
        return result
    }
    Decide(enabled, password, readOnly, role) {
        reason := !enabled ? "TargetDisabled" : password ? "PasswordTarget"
            : readOnly = 1 ? "ReadOnlyTarget" : readOnly != 0 ? "EditableUnknown"
            : role != 50004 && role != 50030 && role != 50003 ? "NonEditableTarget" : "Editable"
        return {state: reason = "Editable" ? "Editable" : "Blocked", reason: reason,
            enabled: enabled, password: password, readOnly: readOnly, role: role, token: 0}
    }
    ReadElement(element, processId) {
        try {
            if !element
                return this.Result("Unknown", "EditableUnknown", "UIA")
            owner := 0, password := 0, enabled := 0, role := 0
            ComCall(20, element, "Int*", &owner)
            ComCall(35, element, "Int*", &password)
            ComCall(28, element, "Int*", &enabled)
            ComCall(21, element, "Int*", &role)
            if owner != processId
                return this.Result("Unknown", "EditableUnknown", "UIA")
            ; Reject ordinary page/document selections unless the provider also
            ; reports the focused text range writable. ValuePattern is optional.
            readOnly := "Unknown"
            if enabled && !password && (role = 50004 || role = 50030 || role = 50003) {
                valueReadOnly := this.ValueReadOnly(element)
                textReadOnly := this.TextReadOnly(element)
                readOnly := valueReadOnly = 1 || textReadOnly = 1 ? 1
                    : valueReadOnly = 0 || textReadOnly = 0 ? 0 : "Unknown"
            }
            result := this.Decide(enabled, password, readOnly, role)
            result.source := "UIA"
            result.elementReference := Format("0x{:X}", element)
            if IsSet(valueReadOnly) {
                result.valueReadOnly := valueReadOnly, result.textReadOnly := textReadOnly
                result.valueReadError := this.valueReadError, result.textReadError := this.textReadError
            }
            if result.state = "Editable"
                result.token := SelectionElement(element), element := 0
            return result
        } finally {
            if element
                ObjRelease(element)
        }
    }
    Pattern(element, id, guid) {
        iid := Buffer(16, 0), pattern := 0
        DllCall("ole32\CLSIDFromString", "WStr", guid, "Ptr", iid)
        ComCall(14, element, "Int", id, "Ptr", iid, "Ptr*", &pattern)
        return pattern
    }
    ValueReadOnly(element) {
        pattern := 0
        this.valueReadError := ""
        try {
            pattern := this.Pattern(element, 10002, "{A94CD8B1-0844-4CD6-9D2D-640537AB39E9}")
            readOnly := 0
            ComCall(5, pattern, "Int*", &readOnly)
            return !!readOnly
        } catch as err {
            this.valueReadError := err.Message
            return "Unknown"
        } finally {
            if pattern
                ObjRelease(pattern)
        }
    }
    TextReadOnly(element) {
        pattern := 0, ranges := 0, textRange := 0, value := Buffer(24, 0)
        this.textReadError := ""
        try {
            pattern := this.Pattern(element, 10014, "{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}")
            ComCall(5, pattern, "Ptr*", &ranges)
            count := 0
            ComCall(3, ranges, "Int*", &count)
            if count = 1
                ComCall(4, ranges, "Int", 0, "Ptr*", &textRange)
            else if count = 0
                ComCall(7, pattern, "Ptr*", &textRange) ; DocumentRange, no GetText.
            else {
                this.textReadError := "MultipleRanges"
                return "Unknown"
            }
            ComCall(9, textRange, "Int", 40015, "Ptr", value) ; IsReadOnly
            if NumGet(value, 0, "UShort") != 11 {
                this.textReadError := "UnsupportedOrMixedAttribute"
                return "Unknown"
            }
            return !!NumGet(value, 8, "Short")
        } catch as err {
            this.textReadError := err.Message
            return "Unknown"
        } finally {
            DllCall("oleaut32\VariantClear", "Ptr", value)
            for ptr in [textRange, ranges, pattern] {
                if ptr
                    ObjRelease(ptr)
            }
        }
    }
    IsCurrent(snapshot, context) {
        if snapshot.source = "NativeEdit"
            return snapshot.controlHwnd = context.controlHwnd && this.ReadNative(snapshot.controlHwnd).state = "Editable"
        if !snapshot.token || !super.IsCurrent(snapshot.token)
            return false
        ; Re-read metadata on the same COM element, without taking ownership.
        ObjAddRef(snapshot.token.ptr)
        return this.ReadElement(snapshot.token.ptr, context.processId).state = "Editable"
    }
}
