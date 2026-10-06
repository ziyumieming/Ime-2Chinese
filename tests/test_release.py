"""Verify publication boundaries without any GitHub writes or credentials."""
import importlib.util
from pathlib import Path
import unittest

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


if __name__ == '__main__':
    unittest.main()
