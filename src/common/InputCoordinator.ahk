#Requires AutoHotkey v2.0

class InputCoordinator {
    __New() => this.owner := ""
    TryEnter(owner) {
        if this.owner != ""
            return false
        this.owner := owner
        return true
    }
    Leave(owner) {
        if this.owner = owner
            this.owner := ""
    }
}
