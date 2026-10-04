#Requires AutoHotkey v2.0

; Active only after a user's explicit click in Settings. No text is collected.
class HotkeyRecorder {
    __New(hwnd, onCandidate, onComplete, onCancel, keyState := unset, foreground := unset) {
        this.hwnd := hwnd, this.onCandidate := onCandidate
        this.onComplete := onComplete, this.onCancel := onCancel
        this.pending := "", this.keyName := "", this.active := false
        this.keyState := IsSet(keyState) ? keyState : (key) => GetKeyState(key, "P")
        this.foregroundReader := IsSet(foreground) ? foreground : () => DllCall("GetForegroundWindow", "Ptr")
    }
    Start() {
        if this.active
            this.Stop()
        this.pending := "", this.keyName := ""
        this.hook := InputHook("L0 I1")
        this.hook.KeyOpt("{All}", "NS")
        this.hook.OnKeyDown := ObjBindMethod(this, "KeyDown")
        this.hook.OnKeyUp := ObjBindMethod(this, "KeyUp")
        this.active := true
        this.hook.Start()
    }
    Modifiers() => (this.keyState.Call("Ctrl") ? "^" : "") (this.keyState.Call("Alt") ? "!" : "")
        . (this.keyState.Call("Shift") ? "+" : "") (this.keyState.Call("LWin") || this.keyState.Call("RWin") ? "#" : "")
    static Build(keyName, modifiers) => HotkeySpec.Parse(modifiers keyName).value
    KeyDown(hook, vk, sc) {
        if !this.active
            return
        if this.foregroundReader.Call() != this.hwnd {
            this.Cancel()
            return
        }
        if vk = 0x10 || vk = 0x11 || vk = 0x12 || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C
            return
        if vk = 0x1B {
            this.Cancel()
            return
        }
        if this.pending != ""
            return
        key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
        try {
            this.pending := HotkeyRecorder.Build(key, this.Modifiers())
            this.keyName := key
            this.onCandidate.Call(this.pending)
        } catch as err {
            this.onCandidate.Call("", err.Message)
        }
    }
    KeyUp(*) {
        if this.active && this.pending != "" && this.Modifiers() = "" && !this.keyState.Call(this.keyName) {
            value := this.pending
            this.Stop()
            this.onComplete.Call(value)
        }
    }
    Stop() {
        this.active := false
        if this.HasOwnProp("hook") {
            this.hook.Stop()
            this.hook.OnKeyDown := "", this.hook.OnKeyUp := ""
        }
    }
    Cancel() {
        if !this.active
            return
        this.Stop()
        this.onCancel.Call()
    }
}
