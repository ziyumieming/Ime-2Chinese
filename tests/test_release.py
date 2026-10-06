"""Verify publication boundaries without any GitHub writes or credentials."""
import importlib.util
from pathlib import Path
import unittest
import tempfile

spec = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[1] / 'tools/release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
VERSION = release.validate_tag('')
TAG = 'v' + VERSION


class FakeApi:
    def __init__(self, published=False, foreign=False, wrong_tag=False):
        self.calls = []
        self.published, self.foreign, self.wrong_tag = published, foreign, wrong_tag

    def request(self, method, path, value=None, binary=False):
        self.calls.append(method)
        if '/git/ref/' in path:
            return {'object': {'type': 'commit', 'sha': 'b' * 40 if self.wrong_tag else 'a' * 40}}
        if '/releases/tags/' in path:
            return {'id': 1, 'draft': not self.published,
                    'author': {'login': 'other' if self.foreign else 'virginialogy[bot]'}}
        raise AssertionError('Unexpected mutation: ' + method)


class ReleaseBoundaries(unittest.TestCase):
    def test_build_only(self):
        self.assertTrue(VERSION)

    def test_mismatched_tag(self):
        with self.assertRaises(ValueError):
            release.validate_tag('v9.9.9')

    def test_wrong_repository(self):
        api = FakeApi()
        with self.assertRaises(ValueError):
            release.create_draft(api, 'other/repo', TAG, {'source_commit': 'a' * 40}, [])
        self.assertEqual(api.calls, [])

    def check_rejected_without_writes(self, api):
        with self.assertRaises(ValueError):
            release.create_draft(api, 'ziyumieming/Ime-2Chinese', TAG, {'source_commit': 'a' * 40}, [])
        self.assertTrue(all(method == 'GET' for method in api.calls))

    def test_wrong_tag_commit(self):
        self.check_rejected_without_writes(FakeApi(wrong_tag=True))

    def test_published_release_protected(self):
        self.check_rejected_without_writes(FakeApi(published=True))

    def test_foreign_draft_protected(self):
        self.check_rejected_without_writes(FakeApi(foreign=True))

    def test_direct_stable_publish_rejected(self):
        api = FakeApi()
        with self.assertRaises(ValueError):
            release.create_draft(api, 'ziyumieming/Ime-2Chinese', 'v1.0.0', {'source_commit': 'a' * 40}, [], True)
        self.assertEqual(api.calls, [])

    def test_public_beta_after_uploads(self):
        self.check_public_beta(False)

    def test_tag_event_retains_complete_published_beta(self):
        class PublishedApi(FakeApi):
            def request(self, method, path, value=None, binary=False):
                result = super().request(method, path, value, binary)
                if '/releases/tags/' in path:
                    result.update(prerelease=True, assets=[{'name': 'package.zip'}, {'name': 'package.sha256'}], html_url='existing beta')
                return result
        api = PublishedApi(published=True)
        release.create_draft(api, 'ziyumieming/Ime-2Chinese', TAG, {'source_commit': 'a' * 40},
                             [Path('package.zip'), Path('package.sha256')], accept_published=True)
        self.assertTrue(all(method == 'GET' for method in api.calls))

    def test_upload_failure_keeps_beta_private(self):
        self.check_public_beta(True)

    def check_public_beta(self, fail_upload):
        class BetaApi:
            def __init__(self):
                self.uploads = 0
                self.published = False
            def request(self, method, path, value=None, binary=False):
                if '/git/ref/tags/' in path or '/releases/tags/' in path:
                    return None
                if '/git/ref/heads/' in path or path.endswith('/git/refs'):
                    return {'object': {'type': 'commit', 'sha': 'a' * 40}}
                if binary:
                    self.uploads += 1
                    if fail_upload:
                        raise RuntimeError('Upload failed')
                    return {'size': len(value)}
                if method == 'PATCH' and value == {'draft': False, 'prerelease': True}:
                    assert self.uploads == 2
                    self.published = True
                return {'id': 1, 'draft': not self.published, 'prerelease': True,
                        'author': {'login': 'virginialogy[bot]'}, 'assets': [],
                        'upload_url': 'https://uploads.github.com/example{?name,label}', 'html_url': 'test beta'}
        api = BetaApi()
        with tempfile.TemporaryDirectory() as directory:
            assets = [Path(directory) / name for name in ['package.zip', 'package.sha256']]
            for asset in assets:
                asset.write_bytes(b'package')
            if fail_upload:
                with self.assertRaises(RuntimeError):
                    release.create_draft(api, 'ziyumieming/Ime-2Chinese', TAG, {'source_commit': 'a' * 40}, assets, True)
            else:
                release.create_draft(api, 'ziyumieming/Ime-2Chinese', TAG, {'source_commit': 'a' * 40}, assets, True)
        self.assertEqual(api.published, not fail_upload)


if __name__ == '__main__':
    unittest.main()
