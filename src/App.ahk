#Requires AutoHotkey v2.0

class App {
    Run(args) {
        if args.Length && args[1] = "--check" {
            FileAppend("IME skeleton loaded; features pending P0 verification.`n", "*")
            ExitApp(0)
        }

        MsgBox("Project bootstrap only. Input features are not active yet.`nSee ROADMAP.md for progress.", "Ime-2Chinese")
        ExitApp(0)
    }
}
