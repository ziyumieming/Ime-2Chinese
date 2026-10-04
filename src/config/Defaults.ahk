#Requires AutoHotkey v2.0

class Defaults {
    static Create() => {enableRefeed: true, enableAutoSwitch: true, startWithWindows: false, refeedHotkey: "!z",
        recoverHotkey: "!+z", sendIntervalMs: 10, maxRefeedLength: 50,
        copyTimeoutMs: 300, refeedTarget: "SogouPinyin", pollIntervalMs: 300,
        defaultAction: "Ignore", rules: []}
}
