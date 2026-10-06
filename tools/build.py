"""Pinned Windows x64 portable build. Standard library only; no installed AHK needed."""
import argparse
import base64
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.task-tmp' / 'toolchain'
DIST = ROOT / 'dist'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(argv, cwd=ROOT, timeout=120):
    result = subprocess.run([str(a) for a in argv], cwd=str(cwd),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    output = result.stdout.decode('utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError('Command failed ({}): {}\n{}'.format(result.returncode, argv[0], output))
    return output


def prepare_tools():
    manifest = json.loads((ROOT / 'tools/toolchain.json').read_text(encoding='utf-8'))
    CACHE.mkdir(parents=True, exist_ok=True)
    for name, item in manifest.items():
        archive = CACHE / (name + '.zip')
        if not archive.exists():
            print('Downloading ' + name, flush=True)
            req = urllib.request.Request(item['url'], headers={'User-Agent': 'Ime-2Chinese-build'})
            with urllib.request.urlopen(req, timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != item['sha256']:
                raise ValueError('Downloaded digest mismatch: ' + name)
            archive.write_bytes(data)
        if digest(archive) != item['sha256']:
            raise ValueError('Cached digest mismatch: ' + name)
    # Extract only the necessary known files. Never execute a global installer.
    for name, filename in [('runtime', 'AutoHotkey64.exe'), ('compiler', 'Ahk2Exe.exe')]:
        directory = CACHE / name
        directory.mkdir(exist_ok=True)
        with zipfile.ZipFile(CACHE / (name + '.zip')) as z:
            directory.joinpath(filename).write_bytes(z.read(filename))
    return CACHE / 'runtime/AutoHotkey64.exe', CACHE / 'compiler/Ahk2Exe.exe', manifest


def resource(module, kind, name):
    api = ctypes.WinDLL('kernel32', use_last_error=True)
    api.FindResourceW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p]
    api.FindResourceW.restype = ctypes.c_void_p
    api.LoadResource.argtypes = [wintypes.HMODULE, ctypes.c_void_p]
    api.LoadResource.restype = ctypes.c_void_p
    api.LockResource.argtypes = [ctypes.c_void_p]
    api.LockResource.restype = ctypes.c_void_p
    api.SizeofResource.argtypes = [wintypes.HMODULE, ctypes.c_void_p]
    handle = api.FindResourceW(module, name, kind)
    if not handle:
        raise ValueError('Missing PE resource')
    size = api.SizeofResource(module, handle)
    return ctypes.string_at(api.LockResource(api.LoadResource(module, handle)), size)


def verify_pe(exe, ico, file_version, product_version):
    data = exe.read_bytes()
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    if data[offset:offset + 4] != b'PE\0\0' or struct.unpack_from('<H', data, offset + 4)[0] != 0x8664:
        raise ValueError('Not a Windows x64 executable')
    version = ctypes.WinDLL('version', use_last_error=True)
    version.GetFileVersionInfoSizeW.argtypes = [wintypes.LPCWSTR, ctypes.c_void_p]
    version.GetFileVersionInfoW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
    version.VerQueryValueW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(wintypes.UINT)]
    size = version.GetFileVersionInfoSizeW(str(exe), None)
    buffer = ctypes.create_string_buffer(size)
    if not size or not version.GetFileVersionInfoW(str(exe), 0, size, buffer):
        raise ValueError('Missing Windows version information')
    ptr, length = ctypes.c_void_p(), wintypes.UINT()
    if not version.VerQueryValueW(buffer, '\\', ctypes.byref(ptr), ctypes.byref(length)):
        raise ValueError('Missing fixed version information')
    fixed = ctypes.cast(ptr, ctypes.POINTER(wintypes.DWORD))
    actual = '{}.{}.{}.{}'.format(fixed[2] >> 16, fixed[2] & 0xffff, fixed[3] >> 16, fixed[3] & 0xffff)
    if actual != file_version:
        raise ValueError('File version mismatch: ' + actual)
    # ProductVersion has the complete beta suffix in addition to fixed numeric fields.
    if product_version.encode('utf-16-le') not in buffer.raw:
        raise ValueError('Product version mismatch')
    api = ctypes.WinDLL('kernel32', use_last_error=True)
    api.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, ctypes.c_void_p, wintypes.DWORD]
    api.LoadLibraryExW.restype = wintypes.HMODULE
    api.FreeLibrary.argtypes = [wintypes.HMODULE]
    module = api.LoadLibraryExW(str(exe), None, 2 | 32)
    if not module:
        raise ValueError('Cannot read executable resources')
    icon_data = ico.read_bytes()
    count = struct.unpack_from('<H', icon_data, 4)[0]
    images = set()
    for i in range(count):
        size, position = struct.unpack_from('<II', icon_data, 6 + 16 * i + 8)
        images.add(icon_data[position:position + size])
    groups = []
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ssize_t)
    def visit(module_handle, kind, name, unused):
        groups.append(resource(module_handle, 14, name))
        return True
    callback = callback_type(visit)
    api.EnumResourceNamesW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, callback_type, ctypes.c_ssize_t]
    try:
        if not api.EnumResourceNamesW(module, 14, callback, 0):
            raise ValueError('No embedded icon groups')
        matches = False
        for group in groups:
            embedded = set()
            for i in range(struct.unpack_from('<H', group, 4)[0]):
                icon_id = struct.unpack_from('<H', group, 6 + 14 * i + 12)[0]
                embedded.add(resource(module, 3, icon_id))
            matches |= embedded == images
        if not matches:
            raise ValueError('Embedded icon differs from supplied artwork')
    finally:
        api.FreeLibrary(module)
    print('PASS x64 PE, file/product version and all {} icon sizes'.format(count), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--prepare-tools', action='store_true')
    args = parser.parse_args()
    if os.name != 'nt':
        raise RuntimeError('Build requires native Windows')
    sys.stdout.reconfigure(errors='backslashreplace')
    ahk, compiler, toolchain = prepare_tools()
    if args.prepare_tools:
        print('Toolchain ready: ' + str(CACHE))
        return
    output = run([sys.executable, ROOT / 'tests/run-tests.py', '--ahk', ahk], timeout=180)
    print(output, flush=True)
    if not re.search(r'\d+ checks, 0 failures', output):
        raise ValueError('Test summary missing')
    info = (ROOT / 'src/config/AppInfo.ahk').read_text(encoding='utf-8')
    version = re.search(r'static Version := "([^"]+)"', info).group(1)
    file_version = re.search(r'static FileVersion := "([\d.]+)"', info).group(1)
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-(?:beta|rc)\.\d+)?', version):
        raise ValueError('Unsupported release version')
    if os.environ.get('GITHUB_REF_TYPE') == 'tag' and os.environ.get('GITHUB_REF_NAME') != 'v' + version:
        raise ValueError('Tag must match AppInfo.Version')
    name = 'Ime-2Chinese-v{}-windows-x64'.format(version)
    DIST.mkdir(exist_ok=True)
    package = DIST / name
    package.mkdir(exist_ok=True)
    exe = package / 'Ime-2Chinese.exe'
    # A clean temporary workspace also proves the compiler does not require the
    # source to be next to the result, or an installed global AutoHotkey.
    with tempfile.TemporaryDirectory(prefix='ime-build-') as temporary:
        stage = Path(temporary)
        icon = stage / 'app.ico'
        icon.write_bytes(base64.b64decode((ROOT / 'assets/app.ico.b64').read_bytes(), validate=False))
        wrapper = stage / 'package.ahk'
        wrapper.write_text(';@Ahk2Exe-SetName Ime-2Chinese\n'
                           ';@Ahk2Exe-SetDescription Chinese input refeed assistant\n'
                           ';@Ahk2Exe-SetVersion ' + file_version + '\n'
                           ';@Ahk2Exe-SetProductVersion ' + version + '\n'
                           '#Include ' + str(ROOT / 'main.ahk') + '\n', encoding='utf-8-sig')
        built = stage / 'Ime-2Chinese.exe'
        print('Compiling standalone EXE', flush=True)
        output = run([compiler, '/in', wrapper, '/out', built, '/base', ahk, '/icon', icon,
                      '/cp', '65001', '/compress', '0', '/silent', 'verbose'], timeout=120)
        print(output, flush=True)
        if not built.is_file():
            raise ValueError('Compiler did not create output')
        verify_pe(built, icon, file_version, version)
        isolated = stage / '独立启动 空目录'
        isolated.mkdir()
        copy = isolated / 'Ime-2Chinese.exe'
        shutil.copy2(built, copy)
        for arguments, expected in [(['--check'], 'modules loaded'), (['--self-test'], 'compiled=1; manual=1; auto=0')]:
            output = run([copy] + arguments, cwd=isolated, timeout=15)
            if expected not in output or 'FAIL ' in output or '==>' in output:
                raise ValueError('Standalone verification failed: ' + output)
            print(output.strip(), flush=True)
        if sorted(p.name for p in isolated.iterdir()) != ['Ime-2Chinese.exe']:
            raise ValueError('Standalone check wrote beside executable')
        shutil.copy2(built, exe)
    shutil.copy2(ROOT / 'docs/portable-guide.md', package / '使用说明.md')
    shutil.copy2(ROOT / 'docs/third-party-notices.md', package / 'THIRD-PARTY-NOTICES.md')
    third_party = package / 'third-party'
    third_party.mkdir(exist_ok=True)
    shutil.copy2(CACHE / 'runtime-source.zip', third_party / 'AutoHotkey-v2.0.19-source.zip')
    with zipfile.ZipFile(CACHE / 'runtime-source.zip') as source:
        (third_party / 'AutoHotkey-GPL-2.0.txt').write_bytes(source.read('AutoHotkey-2.0.19/license.txt'))
    try:
        commit = run(['git', 'rev-parse', 'HEAD']).strip()
        dirty = bool(run(['git', 'status', '--porcelain', '--untracked-files=normal']).strip())
    except (RuntimeError, OSError):
        commit, dirty = 'unknown', True
    metadata = {'version': version, 'file_version': file_version, 'architecture': 'x64',
                'source_commit': commit, 'source_dirty': dirty, 'toolchain': toolchain,
                'exe_sha256': digest(exe), 'verification': 'automated checks and isolated lifecycle; desktop IME UAT pending',
                'icon_sha256': hashlib.sha256(base64.b64decode((ROOT / 'assets/app.ico.b64').read_bytes())).hexdigest()}
    (package / 'build-info.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    # Include only an explicit manifest; stale files from a previous run cannot leak.
    entries = ['Ime-2Chinese.exe', '使用说明.md', 'THIRD-PARTY-NOTICES.md', 'build-info.json',
               'third-party/AutoHotkey-GPL-2.0.txt', 'third-party/AutoHotkey-v2.0.19-source.zip']
    archive = DIST / (name + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
        for item in entries:
            z.write(package / item, name + '/' + item)
    (DIST / (name + '.sha256')).write_text(digest(archive) + '  ' + archive.name + '\n', encoding='ascii')
    print('PASS package: {} ({} bytes)'.format(archive, archive.stat().st_size), flush=True)


if __name__ == '__main__':
    main()
