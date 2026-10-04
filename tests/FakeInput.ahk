#Requires AutoHotkey v2.0

class FakeContext {
    __New() {
        this.identity := 1, this.focused := true
    }
    Capture() => {identity: this.identity, processId: 123}
    IsCurrent(context) => this.focused && context.identity = this.identity
}
class FakeKeys {
    __New() {
        this.released := true
    }
    Release() => this.released
}
class FakeClipboardDriver {
    __New() {
        this.sequenceNumber := 10
        this.value := {text: "old clipboard", image: "bitmap", rich: "formatted"}
        this.selection := "ni hao", this.secondSelection := unset
        this.copies := 0, this.ownerMatchesTarget := true, this.timeout := false
        this.changeOnRead := false, this.changeOnSnapshot := false
        this.throwCopy := false, this.throwRestore := false, this.onCopy := (*) => 0
        this.onClear := (*) => 0
    }
    Sequence() => this.sequenceNumber
    Snapshot() {
        snapshot := this.value.Clone()
        if this.changeOnSnapshot
            this.External("new during snapshot")
        return snapshot
    }
    Clear() {
        this.value := {text: "", image: "", rich: ""}
        this.sequenceNumber += 1
        this.onClear.Call()
    }
    Copy(*) {
        this.copies += 1
        if this.throwCopy
            throw Error("copy failure")
        if !this.timeout {
            text := this.copies > 1 && this.HasOwnProp("secondSelection") ? this.secondSelection : this.selection
            this.value := {text: text, image: "", rich: ""}
            this.sequenceNumber += 1
        }
        this.onCopy.Call()
    }
    Wait(*) => !this.timeout
    Read() {
        text := this.value.text
        if this.changeOnRead
            this.External("new while reading")
        return text
    }
    OwnerMatches(*) => this.ownerMatchesTarget
    Restore(snapshot) {
        if this.throwRestore
            throw Error("restore failure")
        this.value := snapshot.Clone()
        this.sequenceNumber += 1
    }
    External(text) {
        this.value := {text: text, image: "new image", rich: "new rich"}
        this.sequenceNumber += 1
    }
}
class FakeOutput {
    __New() {
        this.deletes := 0, this.letters := "", this.literal := [], this.intervals := []
        this.throwDelete := false, this.throwLetter := false
        this.onLetter := (*) => 0, this.onDelete := (*) => 0
    }
    DeleteSelection() {
        this.deletes += 1
        this.onDelete.Call()
        if this.throwDelete
            throw Error("delete failure")
    }
    SendLetter(letter) {
        if this.throwLetter
            throw Error("letter failure")
        this.letters .= letter
        this.onLetter.Call()
    }
    SendLiteral(text) => this.literal.Push(text)
    Wait(milliseconds) => this.intervals.Push(milliseconds)
}
class PreparedIme {
    __New() {
        this.ok := true, this.calls := 0, this.onPrepare := (*) => 0
    }
    PrepareRefeed(*) {
        this.calls += 1
        this.onPrepare.Call()
        return {ok: this.ok, reason: this.ok ? "Verified" : "TargetImeNotActive"}
    }
    CheckRefeedContext(*) => {ok: true, reason: "Allowed"}
    ReadyForInput(*) => {ok: true, reason: "InputReady"}
}
class FakeSelection {
    Check(*) => {state: "Selected", token: 0}
    IsCurrent(*) => true
}
class FakeEditable {
    __New() => (this.state := "Editable", this.reason := "Editable", this.current := true)
    Check(*) => {state: this.state, reason: this.reason, source: "Fake", token: 0}
    IsCurrent(*) => this.current && this.state = "Editable"
}
