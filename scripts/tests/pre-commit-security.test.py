#!/usr/bin/env python3
"""Exercise the real commit hook and ASP fallback in isolated repositories."""
import base64
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PreCommitSecurityTests(unittest.TestCase):
	def setUp(self):
		self.temp = tempfile.TemporaryDirectory(prefix='asneeded-commit-scan-')
		self.addCleanup(self.temp.cleanup)
		self.repo = Path(self.temp.name) / 'repo'
		self.repo.mkdir()
		toolbin = Path(self.temp.name) / 'bin'
		toolbin.mkdir()
		# Deliberately omit git-secrets to exercise the actual ASP fallback.
		for tool in ['bash', 'git', 'grep', 'cut', 'date', 'mktemp', 'rm', 'basename']:
			(toolbin / tool).symlink_to(shutil.which(tool))
		(toolbin / 'python3').symlink_to(sys.executable)
		self.env = os.environ.copy()
		for name in ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE']:
			self.env.pop(name, None)
		self.env.update(PATH=str(toolbin), GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
		self.git('init', '-q')
		for name in ['.githooks/pre-commit', 'scripts/utilities/asp-preflight.sh', 'scripts/utilities/base64-secret-scan.py']:
			target = self.repo / name
			target.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(ROOT / name, target)

	def git(self, *args):
		return subprocess.run(['git', *args], cwd=self.repo, env=self.env, check=True, capture_output=True)

	def stage(self, content, path='Example.swift'):
		file = self.repo / path
		file.parent.mkdir(parents=True, exist_ok=True)
		file.write_text(content)
		self.git('add', '--', path)
		return file

	def scan(self):
		return subprocess.run(['bash', '.githooks/pre-commit'], cwd=self.repo, env=self.env, capture_output=True, text=True)

	def blocked(self, value):
		result = self.scan()
		self.assertEqual(result.returncode, 1, 'Hook must reject fixture')
		self.assertTrue(value not in result.stdout + result.stderr, 'Hook must redact fixture contents')

	def test_safe_swift(self):
		self.stage('let symbol = SFSafeSymbols.clockArrowTriangleheadCounterclockwiseRotate90\nfunc reconcileScheduledMedicationReminderNotificationRequests() {}\n')
		self.assertEqual(self.scan().returncode, 0)

	def test_provider_token_index(self):
		token = 'ghp_' + 'A' * 36
		file = self.stage(f'let value = "{token}"\n')
		file.write_text('let value = "clean working copy"\n')
		self.blocked(token)

	def test_token_space_path(self):
		token = 'ghp_' + 'B' * 36
		self.stage(f'let value = "{token}"\n', 'Watch App/Example.swift')
		self.blocked(token)

	def test_private_key(self):
		marker = '-' * 5
		marker += 'BEGIN '
		marker += 'RSA '
		marker += bytes([80, 82, 73, 86, 65, 84, 69]).decode('ascii')
		marker += bytes([32, 75, 69, 89]).decode('ascii')
		marker += '-' * 5
		self.stage(marker + '\n', 'fixture.txt')
		self.blocked(marker)

	def test_generic_credential(self):
		value = 'fixture' + 'X' * 24
		name = 'access_' + 'token'
		self.stage(name + ' = ' + value + '\n', 'fixture.txt')
		self.blocked(value)

	def test_encoded_index_space_path(self):
		encoded = base64.b64encode(hashlib.sha512(b'synthetic staged fixture').digest()).decode()
		file = self.stage(f'let value = "{encoded}"\n', 'Watch App/Example.swift')
		file.write_text('let value = "clean working copy"\n')
		self.blocked(encoded)


	def test_historical_path(self):
		path = 'Modules/' + ''.join(('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789AB')) + '.swift'
		self.stage('let count = 1\n', path)
		self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture')
		revision = self.git('rev-parse', 'HEAD').stdout.decode().strip()
		self.git('rm', '--', path)
		command = ['python3', 'scripts/utilities/base64-secret-scan.py', '--path', 'notes.md']
		current = subprocess.run(command, input=path, cwd=self.repo, env=self.env, capture_output=True, text=True)
		historical = subprocess.run(command + ['--revision', revision], input=path, cwd=self.repo, env=self.env, capture_output=True, text=True)
		self.assertEqual(current.returncode, 1)
		self.assertEqual(historical.returncode, 0)

	def test_safe_space_path(self):
		self.stage('let count = 3\n', 'Watch App/Example.swift')
		self.assertEqual(self.scan().returncode, 0)


if __name__ == '__main__':
	unittest.main()
