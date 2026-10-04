#Requires AutoHotkey v2.0

class Notify {
    __New(driver := unset, clock := unset) {
        this.driver := IsSet(driver) ? driver : NativeNotice()
        this.clock := IsSet(clock) ? clock : () => A_TickCount
        this.recent := Map(), this.limit := 20
    }
    Show(message) {
        now := this.clock.Call()
        if this.recent.Has(message) && now - this.recent[message] < 3000
            return
        this.driver.Show(message)
        this.recent[message] := now
        if this.recent.Count > this.limit {
            oldest := "", earliest := now + 1
            for value, tick in this.recent {
                if tick < earliest
                    oldest := value, earliest := tick
            }
            this.recent.Delete(oldest)
        }
    }
}

class NativeNotice {
    Show(message) => TrayTip(message, "Ime-2Chinese")
}
