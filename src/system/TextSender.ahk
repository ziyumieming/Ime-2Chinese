#Requires AutoHotkey v2.0

class NativeTextOutput {
    DeleteSelection() => SendEvent("{BS}")
    SendLetter(letter) => SendEvent(letter)
    SendLiteral(text) => SendText(text)
    Wait(milliseconds) => Sleep(milliseconds)
}

class TextSender {
    __New(driver := unset) {
        this.driver := IsSet(driver) ? driver : NativeTextOutput()
    }

    DeleteSelection(canContinue) {
        if !canContinue.Call()
            return {ok: false, reason: "TargetChanged", changed: false}
        this.driver.DeleteSelection()
        return {ok: true, reason: "Deleted", changed: true}
    }

    SendLetters(letters, intervalMs, canContinue) {
        sent := 0
        try {
        for letter in StrSplit(letters) {
            if !canContinue.Call()
                return {ok: false, reason: "SendingStopped", sent: sent}
            this.driver.SendLetter(letter)
            sent += 1
            this.driver.Wait(intervalMs)
        }
        return {ok: true, reason: "CandidatesReady", sent: sent}
        } catch as err {
            return {ok: false, reason: "SendFailed", sent: sent, error: err.Message, line: err.Line, file: err.File}
        }
    }

    SendOriginal(original, canContinue) {
        if !canContinue.Call()
            return {ok: false, reason: "TargetChanged"}
        this.driver.SendLiteral(original)
        return {ok: true, reason: "OriginalRecovered"}
    }
}
