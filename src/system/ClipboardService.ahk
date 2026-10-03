#Requires AutoHotkey v2.0

class NativeClipboard {
    Sequence() => DllCall("user32\GetClipboardSequenceNumber", "UInt")
    Snapshot() => ClipboardAll()
    Clear() {
        A_Clipboard := ""
    }
    Copy(*) => SendEvent("^c")
    Wait(timeoutMs) => ClipWait(timeoutMs / 1000)
    Read() => A_Clipboard
    Restore(snapshot) {
        A_Clipboard := snapshot
    }
    OwnerMatches(context) {
        owner := DllCall("user32\GetClipboardOwner", "Ptr")
        processId := 0
        if owner
            DllCall("user32\GetWindowThreadProcessId", "Ptr", owner, "UInt*", &processId, "UInt")
        return processId && processId = context.processId
    }
}

class ClipboardService {
    __New(driver := unset) {
        this.driver := IsSet(driver) ? driver : NativeClipboard()
        this.active := false, this.ownedSequence := 0
    }

    Begin() {
        if this.active
            throw Error("Clipboard transaction already active")
        sequence := this.driver.Sequence()
        if !sequence
            throw Error("Clipboard sequence unavailable")
        snapshot := this.driver.Snapshot()
        if this.driver.Sequence() != sequence
            throw Error("Clipboard changed while taking snapshot")
        this.snapshot := snapshot, this.ownedSequence := sequence, this.active := true
    }

    OwnsCurrent() => this.active && this.ownedSequence && this.driver.Sequence() = this.ownedSequence

    ReadSelection(context, timeoutMs, canContinue := unset) {
        if IsSet(canContinue) && !canContinue.Call()
            return {ok: false, reason: "TargetChanged"}
        if !this.OwnsCurrent()
            return {ok: false, reason: "ClipboardChanged"}
        this.driver.Clear()
        this.ownedSequence := this.driver.Sequence()
        if !this.ownedSequence
            return {ok: false, reason: "ClipboardSequenceUnavailable"}
        if IsSet(canContinue) && !canContinue.Call()
            return {ok: false, reason: "TargetChanged"}
        ; Do not adopt clipboard changes until their expected owner is checked.
        this.driver.Copy(context)
        if !this.driver.Wait(timeoutMs)
            return {ok: false, reason: "CopyTimeout"}
        sequence := this.driver.Sequence()
        if !sequence || sequence = this.ownedSequence || !this.driver.OwnerMatches(context)
            return {ok: false, reason: "UnexpectedClipboardOwner"}
        text := this.driver.Read()
        if this.driver.Sequence() != sequence
            return {ok: false, reason: "ClipboardChanged"}
        this.ownedSequence := sequence
        return {ok: true, reason: "Copied", text: text}
    }

    End() {
        if !this.active
            return {ok: true, reason: "NotStarted"}
        try {
            if !this.OwnsCurrent()
                return {ok: true, reason: "NewClipboardPreserved"}
            this.driver.Restore(this.snapshot)
            return {ok: true, reason: "ClipboardRestored"}
        } finally {
            this.active := false, this.ownedSequence := 0
            this.snapshot := "" ; Release all-format backup.
        }
    }
}
