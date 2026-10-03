"""Run bounded AHK checks. Python is a development tool, not an app dependency."""
import argparse
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ahk', default=r'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    checks = [
        ('main.ahk', ['--check'], 'IME P1 modules loaded'),
        ('tests/unit-ime-status.ahk', [], 'PASS 13 IME status cases'),
        ('tests/unit-ime-control.ahk', [], 'PASS 23 assertions'),
        ('tests/unit-config.ahk', [], 'PASS 38 assertions'),
        ('tests/unit-app.ahk', [], 'PASS 31 assertions'),
        ('tests/integration-lifecycle.ahk', [], 'PASS 10 assertions'),
        ('tests/ime-smoke.ahk', ['--check'], 'IME smoke tool loaded'),
        ('tests/ime-diagnostics.ahk', ['--help'], 'Read-only:'),
        ('tests/unit-text-rules.ahk', [], 'PASS 18 assertions'),
        ('tests/unit-clipboard.ahk', [], 'PASS 30 assertions'),
        ('tests/unit-refeed.ahk', [], 'PASS 53 assertions'),
    ]
    failures = 0
    for relative, arguments, expected in checks:
        try:
            result = subprocess.run([args.ahk, '/ErrorStdOut', str(root / relative)] + arguments,
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
