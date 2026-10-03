#Requires AutoHotkey v2.0

; TSF enumeration is session/thread-context information, not a remote-window query.
class ImeProfiles {
    static Clsid := "{33C53A50-F456-4884-B049-85FD643ECFED}"
    static ManagerIid := "{71C6E74C-0F28-11D8-A82A-00065B84435C}"
    static ProfilesIid := "{1F02B6C5-7842-4EE6-8A0B-9A24183A95CA}"
    static KeyboardCategory := "{34745C63-B2F0-4784-8B67-5E12C8701A31}"

    static List(langId := 0) {
        mgr := ComObject(this.Clsid, this.ManagerIid)
        descriptions := ComObject(this.Clsid, this.ProfilesIid)
        enumPtr := 0
        ComCall(6, mgr, "UShort", langId, "Ptr*", &enumPtr)
        items := []
        try {
            data := Buffer(A_PtrSize = 8 ? 88 : 72, 0)
            fetched := 0
            loop {
                hr := ComCall(4, enumPtr, "UInt", 1, "Ptr", data, "UInt*", &fetched, "Int")
                if hr < 0
                    throw Error("TSF enumeration failed",, Format("0x{:08X}", hr & 0xFFFFFFFF))
                if !fetched
                    break
                item := this.Decode(data)
                item.description := this.Description(descriptions, item)
                item.kind := this.Classify(item)
                items.Push(item)
                if hr = 1
                    break
            }
        } finally {
            if enumPtr
                ObjRelease(enumPtr)
        }
        return items
    }

    static GetActive() {
        mgr := ComObject(this.Clsid, this.ManagerIid)
        data := Buffer(A_PtrSize = 8 ? 88 : 72, 0)
        category := this.Guid(this.KeyboardCategory)
        hr := ComCall(10, mgr, "Ptr", category, "Ptr", data, "Int")
        if hr != 0
            return {kind: "Unknown", langId: 0, type: 0, clsid: "", guid: "", description: "", scope: "SessionHint"}
        item := this.Decode(data)
        profiles := ComObject(this.Clsid, this.ProfilesIid)
        item.description := this.Description(profiles, item)
        item.kind := this.Classify(item)
        item.scope := "SessionHint"
        return item
    }

    static Find(kind) {
        matches := []
        for item in this.List(0x0804) {
            if item.kind = kind && item.enabled
                matches.Push(item)
        }
        if matches.Length != 1
            throw Error(matches.Length ? "Ambiguous enabled IME profile" : "Enabled IME profile not found",, kind)
        return matches[1]
    }

    ; Explicit diagnostic opt-in only. FORSESSION can affect other windows.
    ; No ENABLEPROFILE/default-profile/registry-persistence flags are used.
    static ActivateForSession(item) {
        if !item.enabled
            return {ok: false, reason: "ProfileDisabled"}
        mgr := ComObject(this.Clsid, this.ManagerIid)
        clsid := this.Guid(item.clsid)
        profile := this.Guid(item.guid)
        hr := ComCall(3, mgr, "UInt", item.type, "UShort", item.langId,
            "Ptr", clsid, "Ptr", profile, "Ptr", item.hkl, "UInt", 0x20000000, "Int")
        return {ok: hr = 0, reason: hr = 0 ? "Requested" : "ActivationFailed", hresult: hr}
    }

    static Decode(data) {
        flags := NumGet(data, A_PtrSize = 8 ? 80 : 68, "UInt")
        return {type: NumGet(data, 0, "UInt"), langId: NumGet(data, 4, "UShort"),
            clsid: this.GuidText(data.Ptr + 8), guid: this.GuidText(data.Ptr + 24),
            substituteHkl: NumGet(data, 56, "Ptr"),
            hkl: NumGet(data, A_PtrSize = 8 ? 72 : 64, "Ptr"),
            enabled: !!(flags & 2), active: !!(flags & 1), flags: flags}
    }

    static Classify(item) {
        if item.type != 1 || item.langId != 0x0804
            return "Other"
        ; Match registered identity, not localized presentation text.
        if item.clsid = "{E7EA138E-69F8-11D7-A6EA-00065B844310}"
            return "SogouPinyin"
        if item.clsid = "{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}"
            return "MicrosoftPinyin"
        return "Other"
    }

    static Description(profiles, item) {
        if item.type != 1
            return "KeyboardLayout"
        clsid := this.Guid(item.clsid)
        guid := this.Guid(item.guid)
        bstr := 0
        hr := ComCall(12, profiles, "Ptr", clsid, "UShort", item.langId, "Ptr", guid, "Ptr*", &bstr, "Int")
        try return hr = 0 && bstr ? StrGet(bstr, "UTF-16") : ""
        finally {
            if bstr
                DllCall("oleaut32\SysFreeString", "Ptr", bstr)
        }
    }

    static Guid(value) {
        data := Buffer(16, 0)
        hr := DllCall("ole32\CLSIDFromString", "WStr", value, "Ptr", data, "Int")
        if hr < 0
            throw ValueError("Invalid GUID",, value)
        return data
    }

    static GuidText(ptr) {
        text := Buffer(78, 0)
        DllCall("ole32\StringFromGUID2", "Ptr", ptr, "Ptr", text, "Int", 39, "Int")
        return StrGet(text, "UTF-16")
    }
}
