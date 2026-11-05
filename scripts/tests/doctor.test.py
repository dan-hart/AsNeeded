#!/usr/bin/env python3
"""Read-only doctor regressions with synthetic files and command observations."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DoctorTests(unittest.TestCase):
	def setUp(self):
		self.assertTrue((ROOT / 'scripts/doctor.py').exists(), 'read-only doctor is not implemented')
		spec = importlib.util.spec_from_file_location('doctor', ROOT / 'scripts/doctor.py')
		self.doctor = importlib.util.module_from_spec(spec)
		spec.loader.exec_module(self.doctor)
		self.temp = tempfile.TemporaryDirectory()
		self.addCleanup(self.temp.cleanup)
		self.root = Path(self.temp.name)
		for relative in ['AsNeeded.xcodeproj/project.pbxproj', self.doctor.LOCKFILE, '.githooks/pre-commit', '.githooks/pre-push', 'scripts/scan-repo.sh', 'scripts/utilities/asp-preflight.sh', 'scripts/utilities/base64-secret-scan.py']:
			path = self.root / relative
			path.parent.mkdir(parents=True, exist_ok=True)
			path.write_text('')
			path.chmod(0o755)
		(self.root / 'scripts/utilities/base64-secret-scan.py').chmod(0o644)
		(self.root / 'AsNeeded.xcodeproj/project.pbxproj').write_text('IPHONEOS_DEPLOYMENT_TARGET = 26.0;')
		(self.root / self.doctor.LOCKFILE).write_text(json.dumps({'version': 3, 'pins': [{'identity': 'synthetic', 'state': {'revision': 'a' * 40}}]}))
		self.responses = {
			('xcode-select', '-p'): '/Applications/Xcode.app/Contents/Developer',
			('xcodebuild', '-version'): 'Xcode 26.1\nBuild version synthetic',
			('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'): '26.1',
			('xcrun', 'swift', '--version'): 'Apple Swift version 6.2.1 (synthetic)',
			('xcrun', 'simctl', 'list', 'devices', 'available', '--json'): json.dumps({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-26-1': [{'name': 'iPhone synthetic', 'isAvailable': True, 'udid': 'PRIVATE_DEVICE_ID'}]}}),
			('git', 'config', '--get', 'core.hooksPath'): '.githooks',
		}
		self.commands = []

	def run_stub(self, command, root):
		self.commands.append(tuple(command))
		if tuple(command) not in self.responses:
			raise AssertionError(f'Unexpected command: {command}')
		return self.responses[tuple(command)]

	def report(self):
		from unittest.mock import patch
		with patch.dict('os.environ', {}, clear=True):
			return self.doctor.diagnose(self.root, run=self.run_stub)

	def check(self, report, name):
		return next(item for item in report['checks'] if item['id'] == name)

	def test_healthy_environment_has_only_optional_config_warning(self):
		report = self.report()
		self.assertTrue(report['ok'])
		self.assertEqual(self.check(report, 'purchase_config')['status'], 'warning')
		self.assertNotIn('PRIVATE_DEVICE_ID', json.dumps(report))
		self.assertNotIn('/Applications/', json.dumps(report))
		self.assertEqual(set(self.commands), set(self.responses))

	def test_missing_tools_fail_without_echoing_command_output(self):
		for command in list(self.responses):
			self.responses[command] = None
		report = self.report()
		self.assertFalse(report['ok'])
		self.assertEqual(self.check(report, 'xcode')['status'], 'failure')

	def test_only_available_compatible_iphones_count(self):
		self.responses[('xcrun', 'simctl', 'list', 'devices', 'available', '--json')] = json.dumps({'devices': {
			'com.apple.CoreSimulator.SimRuntime.iOS-18-5': [{'name': 'iPhone old', 'isAvailable': True}],
			'com.apple.CoreSimulator.SimRuntime.iOS-26-1': [{'name': 'iPad', 'isAvailable': True}, {'name': 'iPhone unavailable', 'isAvailable': False}],
		}})
		report = self.report()
		self.assertFalse(report['ok'])
		self.assertEqual(self.check(report, 'simulators')['status'], 'failure')

	def test_missing_or_unpinned_lockfile_fails(self):
		for content in ['invalid JSON', '{"version":3,"pins":[]}', '{"version":3,"pins":[{"identity":"floating","state":{"branch":"main"}}]}']:
			(self.root / self.doctor.LOCKFILE).write_text(content)
			self.assertEqual(self.check(self.report(), 'packages')['status'], 'failure')

	def test_purchase_configuration_presence_never_reads_contents(self):
		config = self.root / 'Config/Secrets.xcconfig'
		config.parent.mkdir()
		config.write_text('PRIVATE_CONFIGURATION_SENTINEL')
		original = Path.read_text
		def guarded(path, *args, **kwargs):
			if path == config:
				raise AssertionError('Doctor read purchase configuration')
			return original(path, *args, **kwargs)
		from unittest.mock import patch
		with patch.object(Path, 'read_text', guarded):
			report = self.report()
		self.assertEqual(self.check(report, 'purchase_config')['status'], 'pass')
		self.assertNotIn('PRIVATE_CONFIGURATION_SENTINEL', json.dumps(report))

	def test_missing_hooks_and_scanner_fail(self):
		(self.root / '.githooks/pre-commit').chmod(0o644)
		(self.root / 'scripts/scan-repo.sh').unlink()
		report = self.report()
		self.assertEqual(self.check(report, 'hooks')['status'], 'failure')
		self.assertEqual(self.check(report, 'scanner')['status'], 'failure')

	def test_old_toolchain_and_malformed_inventory_fail(self):
		self.responses[('xcodebuild', '-version')] = 'Xcode 25.0'
		self.responses[('xcrun', 'swift', '--version')] = 'Swift version 6.1'
		self.responses[('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version')] = '18.5'
		self.responses[('xcrun', 'simctl', 'list', 'devices', 'available', '--json')] = 'PRIVATE_BAD_OUTPUT'
		report = self.report()
		for check in ('xcode', 'compiler', 'sdk', 'simulators'):
			self.assertEqual(self.check(report, check)['status'], 'failure')
		self.assertNotIn('PRIVATE_BAD_OUTPUT', json.dumps(report))

	def test_observations_preserve_files(self):
		before = {str(path.relative_to(self.root)): (path.read_bytes(), path.stat().st_mode) for path in self.root.rglob('*') if path.is_file()}
		self.report()
		after = {str(path.relative_to(self.root)): (path.read_bytes(), path.stat().st_mode) for path in self.root.rglob('*') if path.is_file()}
		self.assertEqual(before, after)

	def test_cli_json_and_human_reports_and_failure_exit(self):
		import contextlib
		import io
		from unittest.mock import patch
		for healthy in (True, False):
			for json_mode in (True, False):
				report = {'ok': healthy, 'checks': [{'id': 'synthetic', 'status': 'pass' if healthy else 'failure', 'message': 'Synthetic observation.'}]}
				output = io.StringIO()
				with patch.object(self.doctor, 'diagnose', return_value=report), contextlib.redirect_stdout(output):
					code = self.doctor.main(['--root', str(self.root)] + (['--json'] if json_mode else []))
				self.assertEqual(code, 0 if healthy else 1)
				if json_mode:
					self.assertEqual(json.loads(output.getvalue()), report)
				else:
					self.assertIn('Synthetic observation.', output.getvalue())


if __name__ == '__main__':
	unittest.main()
