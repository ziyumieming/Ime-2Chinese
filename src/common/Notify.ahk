#Requires AutoHotkey v2.0

class Notify {
    __New() {
        this.lastMessage := "", this.lastTick := 0
    }
    Show(message) {
        if message = this.lastMessage && A_TickCount - this.lastTick < 3000
            return
        this.lastMessage := message, this.lastTick := A_TickCount
        TrayTip(message, "Ime-2Chinese")
    }
}
