#!/usr/bin/env python3
"""Exercise the real push hook against isolated local repositories, never a live remote."""
import base64
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / '.githooks/pre-push'


class PushScannerTests(unittest.TestCase):
	def setUp(self):
		self.directory = tempfile.TemporaryDirectory(prefix='asneeded-hook-test-')
		self.addCleanup(self.directory.cleanup)
		self.repo = Path(self.directory.name) / 'source'
		self.repo.mkdir()
		self.remote = Path(self.directory.name) / 'remote.git'
		self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)
		self.git('init', '-b', 'main')
		self.git('config', 'user.name', 'Synthetic Hook Test')
		self.git('config', 'user.email', 'hook-test@example.invalid')
		self.git('init', '--bare', str(self.remote))
		self.git('remote', 'add', 'origin', str(self.remote))
		self.commit_file('README.md', 'Synthetic baseline\n')
		self.git('push', 'origin', 'main')
		helper = self.repo / 'scripts/utilities/base64-secret-scan.py'
		helper.parent.mkdir(parents=True)
		shutil.copyfile(ROOT / 'scripts/utilities/base64-secret-scan.py', helper)
		self.git('add', str(helper.relative_to(self.repo)))
		self.git('commit', '-m', 'Add synthetic scanner harness')

	def git(self, *arguments):
		return subprocess.check_output(['git', *arguments], cwd=self.repo, env=self.env, stderr=subprocess.PIPE).decode().strip()

	def commit_file(self, filename, text):
		path = self.repo / filename
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(text)
		self.git('add', filename)
		self.git('commit', '-m', 'Synthetic scanner fixture')

	def scan(self):
		sha = self.git('rev-parse', 'HEAD')
		before = self.git('status', '--porcelain')
		result = subprocess.run(
			['bash', str(HOOK), 'origin', str(self.remote)], cwd=self.repo, env=self.env,
			input=f'refs/heads/main {sha} refs/heads/testing {"0" * 40}\n',
			capture_output=True, text=True)
		self.assertEqual(self.git('rev-parse', 'HEAD'), sha, 'Push hook must not create commits')
		self.assertEqual(self.git('status', '--porcelain'), before, 'Push hook must not edit files')
		return result

	def test_source_names_and_version_are_preserved(self):
		self.commit_file('AsNeeded.xcodeproj/project.pbxproj', 'CURRENT_PROJECT_VERSION = 317;\n')
		self.commit_file('Watch App/Example.swift', 'func reconcileScheduledMedicationReminderNotificationRequests() {}\n')
		result = self.scan()
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertIn('317', (self.repo / 'AsNeeded.xcodeproj/project.pbxproj').read_text())

	def test_provider_token_in_spaced_path_is_blocked_and_redacted(self):
		token = 'ghp_' + 'A' * 36
		self.commit_file('Watch App/Example.swift', f'let value = "{token}"\n')
		result = self.scan()
		self.assertNotEqual(result.returncode, 0)
		self.assertNotIn(token, result.stdout + result.stderr)

	def test_private_key_header_is_blocked(self):
		header = '-' * 5
		header += 'BEGIN '
		header += bytes([80, 82, 73, 86, 65, 84, 69]).decode('ascii')
		header += bytes([32, 75, 69, 89]).decode('ascii')
		header += '-' * 5
		self.commit_file('fixture.txt', header + '\n')
		result = self.scan()
		self.assertNotEqual(result.returncode, 0)
		self.assertNotIn(header, result.stdout + result.stderr)

	def test_unknown_encoded_secret_is_blocked(self):
		value = base64.b64encode(hashlib.sha512(b'synthetic push fixture').digest()).decode()
		self.commit_file('Example.swift', f'let value = "{value}"\n')
		result = self.scan()
		self.assertNotEqual(result.returncode, 0)
		self.assertNotIn(value, result.stdout + result.stderr)

	def test_removing_secret_from_tip_does_not_hide_outgoing_ancestor(self):
		token = 'ghp_' + 'B' * 36
		self.commit_file('Example.swift', f'let value = "{token}"\n')
		self.commit_file('Example.swift', 'let value = "removed"\n')
		self.assertNotEqual(self.scan().returncode, 0)


if __name__ == '__main__':
	unittest.main()
