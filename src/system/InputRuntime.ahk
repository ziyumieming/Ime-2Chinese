#Requires AutoHotkey v2.0

class NativeInputContext {
    Capture() => WindowContext.GetActive()
    IsCurrent(context) => WindowContext.IsCurrent(context)
}

class TriggerKeys {
    Release() => KeyWait("Alt", "T1") && KeyWait("Control", "T1") && KeyWait("Shift", "T1")
        && KeyWait("LWin", "T1") && KeyWait("RWin", "T1")
}

class PollScheduler {
    Start(callback, intervalMs) => SetTimer(callback, intervalMs)
    Stop(callback) => SetTimer(callback, 0)
}
