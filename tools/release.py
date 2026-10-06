"""Create draft releases using the designated GitHub App installation token only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def validate_tag(tag):
    version = re.search(r'static Version := "([^"]+)"',
                        (ROOT / 'src/config/AppInfo.ahk').read_text(encoding='utf-8')).group(1)
    if tag and (not re.fullmatch(r'v\d+\.\d+\.\d+(?:-(?:beta|rc)\.\d+)?', tag) or tag != 'v' + version):
        raise ValueError('Release tag must equal v' + version)
    return version


def validate_bundle(tag, directory):
    version = validate_tag(tag)
    if not tag:
        raise ValueError('Release requires an existing version tag')
    name = 'Ime-2Chinese-v{}-windows-x64'.format(version)
    archive = directory / (name + '.zip')
    checksum = directory / (name + '.sha256')
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if checksum.read_text(encoding='ascii').strip() != actual + '  ' + archive.name:
        raise ValueError('Package checksum mismatch')
    with zipfile.ZipFile(archive) as z:
        info = json.loads(z.read(name + '/build-info.json'))
        executable = z.read(name + '/Ime-2Chinese.exe')
    if (info['version'] != version or info['source_dirty'] or
            not re.fullmatch(r'[0-9a-f]{40}', info['source_commit']) or
            info['exe_sha256'] != hashlib.sha256(executable).hexdigest()):
        raise ValueError('Package provenance mismatch or dirty source')
    return info, [archive, checksum]


class Api:
    def __init__(self, token):
        if not token:
            raise ValueError('Missing App installation token')
        self.token = token

    def request(self, method, path, value=None, binary=False):
        url = path if path.startswith('https://uploads.github.com/') else 'https://api.github.com' + path
        data = value if binary else (json.dumps(value).encode('utf-8') if value is not None else None)
        headers = {'Authorization': 'Bearer ' + self.token, 'Accept': 'application/vnd.github+json',
                   'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'Ime-2Chinese-release',
                   'Content-Type': 'application/octet-stream' if binary else 'application/json'}
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                content = response.read()
                return json.loads(content) if content else None
        except urllib.error.HTTPError as exc:
            if exc.code == 404 and method == 'GET':
                return None
            # Do not dump headers, environment, request or credentials.
            raise RuntimeError('GitHub API {} failed with HTTP {}'.format(method, exc.code)) from None


def create_draft(api, repository, tag, info, assets, publish_beta=False, accept_published=False):
    if repository != 'ziyumieming/Ime-2Chinese':
        raise ValueError('Release target is not the authorized repository')
    if publish_beta and not re.fullmatch(r'v\d+\.\d+\.\d+-(?:beta|rc)\.\d+', tag):
        raise ValueError('Direct publishing is limited to beta/rc releases')
    prefix = '/repos/' + repository
    ref = api.request('GET', prefix + '/git/ref/tags/' + urllib.parse.quote(tag, safe=''))
    if not ref and publish_beta:
        main_ref = api.request('GET', prefix + '/git/ref/heads/main')
        if not main_ref or main_ref['object']['sha'] != info['source_commit']:
            raise ValueError('New beta tag must point to the current packaged main commit')
        ref = api.request('POST', prefix + '/git/refs', {'ref': 'refs/tags/' + tag, 'sha': info['source_commit']})
    if not ref:
        raise ValueError('Tag must already exist; release must not create it implicitly')
    obj = ref['object']
    for _ in range(5):
        if obj['type'] != 'tag':
            break
        obj = api.request('GET', prefix + '/git/tags/' + obj['sha'])['object']
    if obj['type'] != 'commit' or obj['sha'] != info['source_commit']:
        raise ValueError('Existing tag does not point to packaged source')
    release = api.request('GET', prefix + '/releases/tags/' + urllib.parse.quote(tag, safe=''))
    if release and not release['draft'] and accept_published:
        names = {asset['name'] for asset in release.get('assets', [])}
        if (release['author']['login'] == 'virginialogy[bot]' and release['prerelease'] == ('-' in tag)
                and all(asset.name in names for asset in assets)):
            print('Existing published release retained: ' + release['html_url'])
            return
    if release and (not release['draft'] or release['author']['login'] != 'virginialogy[bot]'):
        raise ValueError('Refusing to overwrite a published or foreign release')
    body = ('Windows x64 便携包，无需安装 AutoHotkey。\n\n'
            '手动重喂/取回原文、设置、诊断导出和登录自启已集成；窗口自动切换继续冻结。\n\n'
            '自动检查和独立 EXE 生命周期已通过，完整桌面 UAT 的结论以 Issue #4 为准。'
            + ('此为公开测试版，供桌面 UAT；不标为稳定版本。' if publish_beta else '公开发布前请完成验收并编辑本草稿。')
            + '\n\n源提交：`' + info['source_commit'] + '`。')
    values = {'tag_name': tag, 'name': 'Ime-2Chinese ' + tag, 'body': body,
              'draft': True, 'prerelease': '-' in tag}
    if release:
        release = api.request('PATCH', prefix + '/releases/' + str(release['id']), values)
    else:
        release = api.request('POST', prefix + '/releases', values)
    if release['author']['login'] != 'virginialogy[bot]' or not release['draft']:
        raise ValueError('Unexpected release author or visibility')
    # Only replace package/checksum assets in a bot-owned draft. Published assets
    # and other manually attached files are left untouched.
    existing = {a['name']: a for a in release.get('assets', [])}
    for path in assets:
        if path.name in existing:
            api.request('DELETE', prefix + '/releases/assets/' + str(existing[path.name]['id']))
        upload_url = release['upload_url'].split('{')[0] + '?name=' + urllib.parse.quote(path.name)
        uploaded = api.request('POST', upload_url, path.read_bytes(), binary=True)
        if uploaded['size'] != path.stat().st_size:
            raise ValueError('Uploaded asset size mismatch')
        if uploaded.get('digest') and uploaded['digest'] != 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest():
            raise ValueError('Uploaded asset digest mismatch')
    if publish_beta:
        release = api.request('PATCH', prefix + '/releases/' + str(release['id']), {'draft': False, 'prerelease': True})
        if release['draft'] or not release['prerelease'] or release['author']['login'] != 'virginialogy[bot]':
            raise ValueError('Unexpected published release status or author')
    print(('Public prerelease published' if publish_beta else 'Draft release prepared')
          + ' by virginialogy[bot]: ' + release['html_url'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--validate-tag', action='store_true')
    args = parser.parse_args()
    tag = os.environ.get('RELEASE_TAG', '')
    publish_beta = os.environ.get('PUBLISH_BETA', 'false').lower() == 'true'
    if publish_beta:
        if tag or os.environ.get('GITHUB_REF') != 'refs/heads/main':
            raise ValueError('Publish beta requires current main with release_tag empty')
        tag = 'v' + validate_tag('')
        if not re.fullmatch(r'v\d+\.\d+\.\d+-(?:beta|rc)\.\d+', tag):
            raise ValueError('Direct publishing is limited to beta/rc releases')
    validate_tag(tag)
    if args.validate_tag:
        print('Release input validated; ' + (tag if tag else 'build only'))
        return
    if os.environ.get('APP_SLUG') != 'virginialogy':
        raise ValueError('Only the virginialogy GitHub App may create releases')
    info, assets = validate_bundle(tag, ROOT / 'dist')
    accept_published = not publish_beta and os.environ.get('GITHUB_REF_TYPE') == 'tag'
    create_draft(Api(os.environ.get('GH_TOKEN')), os.environ.get('GITHUB_REPOSITORY'), tag, info, assets, publish_beta, accept_published)


if __name__ == '__main__':
    main()
