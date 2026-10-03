#Requires AutoHotkey v2.0

class NativeHotkeys {
    Enable(key, callback) => Hotkey(key, callback, "On T1")
    Disable(key) => Hotkey(key, "Off")
}

class HotkeyBindings {
    __New(driver := unset) {
        this.driver := IsSet(driver) ? driver : NativeHotkeys(), this.active := []
    }
    Apply(bindings) {
        previous := this.active.Clone()
        this.Clear()
        try {
            for binding in bindings {
                this.driver.Enable(binding.key, binding.callback)
                this.active.Push(binding)
            }
        } catch as err {
            this.Clear()
            try {
                for binding in previous {
                    this.driver.Enable(binding.key, binding.callback)
                    this.active.Push(binding)
                }
            } catch {
                this.Clear()
                throw Error("热键注册和恢复失败；热键已停用。")
            }
            throw err
        }
    }
    Clear() {
        ; Propagate disable failures instead of pretending cleanup succeeded.
        while this.active.Length {
            binding := this.active[this.active.Length]
            this.driver.Disable(binding.key)
            this.active.Pop()
        }
    }
}
