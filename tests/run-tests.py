"""Run bounded AHK checks. Python is a development tool, not an app dependency."""
import argparse
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ahk', default=r'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe')
    args = parser.parse_args()
    # A console code page must not hide a failure containing Unicode paths/text.
    sys.stdout.reconfigure(errors='backslashreplace')
    root = Path(__file__).resolve().parents[1]
    checks = [
        ('main.ahk', ['--check'], 'IME P1/P2/P3/P4/P5 modules loaded'),
        ('tests/unit-ime-status.ahk', [], 'PASS 13 IME status cases'),
        ('tests/unit-ime-control.ahk', [], 'PASS 23 assertions'),
        ('tests/unit-config.ahk', [], 'PASS 42 assertions'),
        ('tests/unit-app.ahk', [], 'PASS 40 assertions'),
        ('tests/integration-lifecycle.ahk', [], 'PASS 10 assertions'),
        ('tests/ime-smoke.ahk', ['--check'], 'IME smoke tool loaded'),
        ('tests/ime-diagnostics.ahk', ['--help'], 'Read-only:'),
        ('tests/unit-text-rules.ahk', [], 'PASS 18 assertions'),
        ('tests/unit-clipboard.ahk', [], 'PASS 30 assertions'),
        ('tests/unit-refeed.ahk', [], 'PASS 53 assertions'),
        ('tests/refeed-mvp.ahk', ['--check'], 'IME P1/P2/P3/P4/P5 modules loaded'),
        ('tests/unit-rules.ahk', [], 'PASS 44 assertions'),
        ('tests/unit-window-context.ahk', [], 'PASS 18 assertions'),
        ('tests/unit-app-rules.ahk', [], 'PASS 23 assertions'),
        ('tests/unit-refeed-feedback.ahk', [], 'PASS 20 assertions'),
        ('tests/unit-ime-ready.ahk', [], 'PASS 18 assertions'),
        ('tests/unit-selection.ahk', [], 'PASS 11 assertions'),
        ('tests/unit-auto-switch.ahk', [], 'PASS 39 assertions'),
        ('tests/unit-app-auto.ahk', [], 'PASS 38 assertions'),
        ('tests/features-mvp.ahk', ['--check'], 'IME P1/P2/P3/P4/P5 modules loaded'),
        ('tests/unit-settings.ahk', [], 'PASS 29 assertions'),
        ('tests/unit-app-settings.ahk', [], 'PASS 40 assertions'),
        ('tests/unit-diagnostics.ahk', [], 'PASS 19 assertions'),
        ('tests/integration-settings.ahk', [], 'PASS 24 assertions'),
    ]
    failures = 0
    for relative, arguments, expected in checks:
        try:
            result = subprocess.run([args.ahk, '/ErrorStdOut=UTF-8', str(root / relative)] + arguments,
                                    cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=10)
            output = result.stdout.decode('utf-8', errors='replace').strip()
            # AHK may return 0 for startup errors; output is part of the contract.
            passed = result.returncode == 0 and expected in output and '==>' not in output and 'FAIL ' not in output
        except (OSError, subprocess.TimeoutExpired) as exc:
            passed, output = False, str(exc)
        print(('PASS ' if passed else 'FAIL ') + relative)
        print(output)
        failures += not passed
    print('{} checks, {} failures; third-party IME compatibility remains untested.'.format(len(checks), failures))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
