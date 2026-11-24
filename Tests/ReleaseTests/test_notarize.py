import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

path = Path(__file__).resolve().parents[2] / 'Scripts' / 'notarize.py'
spec = importlib.util.spec_from_file_location('notarize', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NotarizationTests(unittest.TestCase):
    def test_rejects_adhoc_or_missing_runtime_and_timestamp(self):
        for report in ['Signature=adhoc', 'Authority=Developer ID Application: Test\nTeamIdentifier=TEAM123456\nTimestamp=Today',
                       'Authority=Developer ID Application: Test\nTeamIdentifier=TEAM123456\nflags=runtime']:
            with self.subTest(report=report), self.assertRaises(module.NotarizationError):
                module.validate_signature(report)

    def test_accepts_developer_id_with_required_protections(self):
        module.validate_signature('Authority=Developer ID Application: Test\nTeamIdentifier=TEAM123456\nTimestamp=Today\nCodeDirectory v=20500 flags=0x10000(runtime)')

    def test_only_accepted_status_can_proceed(self):
        for status in ['In Progress', 'Submitted', 'Invalid', 'Rejected', 'Unknown']:
            with self.subTest(status=status), self.assertRaises(module.NotarizationError):
                module.require_accepted({'status': status})
        module.require_accepted({'status': 'Accepted'})

    def test_failed_stapling_never_creates_distribution_archive(self):
        with tempfile.TemporaryDirectory() as folder:
            calls = []
            def fail(args, **kwargs):
                calls.append(args)
                raise module.NotarizationError('stapling failed')
            with self.assertRaises(module.NotarizationError):
                module.complete_accepted(Path(folder) / 'NotchCopy.app', Path(folder), '0.4.1', fail)
            self.assertEqual(len(calls), 1)
            self.assertFalse(list(Path(folder).glob('*.zip')))

    def test_gatekeeper_must_pass_before_packaging(self):
        with tempfile.TemporaryDirectory() as folder:
            calls = []
            def mock(args, **kwargs):
                calls.append([str(x) for x in args])
                if args[0] == 'spctl':
                    raise module.NotarizationError('Gatekeeper denied')
                return subprocess.CompletedProcess(args, 0, '', '')
            with self.assertRaises(module.NotarizationError):
                module.complete_accepted(Path(folder) / 'NotchCopy.app', Path(folder), '0.4.1', mock)
            self.assertFalse(any(c[0] == 'ditto' for c in calls))

    def test_success_packages_stapled_app_and_generates_checksum(self):
        with tempfile.TemporaryDirectory() as folder:
            calls = []
            def mock(args, **kwargs):
                calls.append([str(x) for x in args])
                if args[0] == 'ditto':
                    Path(args[-1]).write_bytes(b'stapled-app-zip')
                return subprocess.CompletedProcess(args, 0, '', '')
            output = Path(folder)
            archive = module.complete_accepted(output / 'NotchCopy.app', output, '0.4.1', mock)
            self.assertTrue(archive.exists())
            self.assertEqual(calls[0][:3], ['xcrun', 'stapler', 'staple'])
            self.assertEqual(calls[1][:3], ['xcrun', 'stapler', 'validate'])
            self.assertEqual(calls[-1][0], 'ditto')
            self.assertIn(archive.name, (output / 'SHA256SUMS.txt').read_text())

    def test_missing_identity_stops_before_build_or_submission(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'VERSION').write_text('0.4.1')
            calls = []
            def mock(args, **kwargs):
                calls.append(args)
                return subprocess.CompletedProcess(args, 0, '0 valid identities', '')
            with self.assertRaises(module.NotarizationError):
                module.notarize('Developer ID Application: Test (TEAM)', 'profile', root=root, runner=mock)
            self.assertEqual(len(calls), 1)
            self.assertFalse(any('submit' in c for c in calls))


    def pending(self, folder):
        import hashlib
        import json
        root = Path(folder)
        (root / 'VERSION').write_text('0.4.1')
        output = root / 'dist/notarized/v0.4.1'
        binary = output / 'NotchCopy.app/Contents/MacOS/NotchCopy'
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b'signed-candidate')
        state = {'id': 'submission-id', 'version': '0.4.1', 'status': 'Submitted',
                 'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
        (output / 'notarization.json').write_text(json.dumps(state))
        return root, output, binary

    def test_pending_submission_is_not_uploaded_twice(self):
        with tempfile.TemporaryDirectory() as folder:
            root, output, binary = self.pending(folder)
            def forbidden(*args, **kwargs):
                self.fail('existing submission must not be uploaded again')
            with self.assertRaises(module.NotarizationError):
                module.notarize('Developer ID Application: Test (TEAM123456)', 'profile', root=root, runner=forbidden)

    def test_resume_rejects_changed_candidate_before_network_access(self):
        with tempfile.TemporaryDirectory() as folder:
            root, output, binary = self.pending(folder)
            binary.write_bytes(b'changed-after-submission')
            def forbidden(*args, **kwargs):
                self.fail('changed candidates must not use old submissions')
            with self.assertRaises(module.NotarizationError):
                module.notarize(None, 'profile', resume=True, root=root, runner=forbidden)

    def test_invalid_result_cannot_staple_or_package(self):
        with tempfile.TemporaryDirectory() as folder:
            root, output, binary = self.pending(folder)
            calls = []
            def mock(args, **kwargs):
                calls.append([str(x) for x in args])
                return subprocess.CompletedProcess(args, 0, '{"status":"Invalid"}', '')
            with self.assertRaises(module.NotarizationError):
                module.notarize(None, 'profile', resume=True, root=root, runner=mock)
            self.assertTrue(any('log' in call for call in calls))
            self.assertFalse(any('stapler' in call or 'ditto' in call for call in calls))

    def test_timeout_keeps_submission_for_resume_without_packaging(self):
        import json
        with tempfile.TemporaryDirectory() as folder:
            root, output, binary = self.pending(folder)
            calls = []
            def mock(args, **kwargs):
                calls.append(args)
                return subprocess.CompletedProcess(args, 1, '{"status":"In Progress"}', '')
            with self.assertRaises(module.NotarizationError):
                module.notarize(None, 'profile', resume=True, root=root, runner=mock)
            state = json.loads((output / 'notarization.json').read_text())
            self.assertEqual(state['id'], 'submission-id')
            self.assertEqual(state['status'], 'In Progress')
            self.assertEqual(len(calls), 1)
            self.assertFalse(list(output.glob('*.zip')))


if __name__ == '__main__':
    unittest.main()
