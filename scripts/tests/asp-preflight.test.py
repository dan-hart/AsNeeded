#!/usr/bin/env python3
"""Exercise display categorization and catalog secret scanning in temporary Git repos."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREFLIGHT = ROOT / 'scripts/utilities/asp-preflight.sh'


class AspPreflightTests(unittest.TestCase):
	def setUp(self):
		self.directory = tempfile.TemporaryDirectory(prefix='asneeded-preflight-test-')
		self.addCleanup(self.directory.cleanup)
		self.repo = Path(self.directory.name)
		self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)
		self.git('init', '-b', 'main')
		self.git('config', 'user.name', 'Synthetic Preflight Test')
		self.git('config', 'user.email', 'preflight-test@example.invalid')
		if shutil.which('git-secrets'):
			self.git('secrets', '--add', 'synthetic-preflight-blocked-fixture')

	def git(self, *arguments):
		return subprocess.check_output(['git', *arguments], cwd=self.repo, env=self.env, stderr=subprocess.PIPE).decode().strip()

	def stage(self, name, text):
		path = self.repo / name
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(text)
		self.git('add', name)

	def scan(self, *arguments):
		return subprocess.run(['bash', str(PREFLIGHT), '--staged', '--strict', *arguments],
			cwd=self.repo, env=self.env, capture_output=True, text=True)

	def test_french_catalog_additions_and_deletions_need_no_display_ack(self):
		word = 'nou' + 'veau'
		name = 'AsNeeded/Localizable.xcstrings'
		self.stage(name, json.dumps({'value': 'Un ' + word + ' médicament'}, ensure_ascii=False) + '\n')
		self.git('commit', '-m', 'Synthetic baseline')
		self.stage(name, json.dumps({'value': 'Ajouter un ' + word + ' médicament'}, ensure_ascii=False) + '\n')
		result = self.scan()
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertNotIn('display/graphics changes detected', result.stderr)

	def test_actual_driver_configuration_still_requires_display_ack(self):
		self.stage('graphics.conf', 'driver=' + 'nou' + 'veau' + '\n')
		result = self.scan()
		self.assertEqual(result.returncode, 2, result.stderr)
		self.assertIn('--ack-display', result.stderr)
		self.assertEqual(self.scan('--ack-display').returncode, 0)

	def test_catalog_secret_is_still_blocked(self):
		fixture = 'sk-' + 'proj-' + 'X' * 24
		if shutil.which('git-secrets'):
			self.git('secrets', '--add', '--literal', fixture)
		self.stage('AsNeeded/Localizable.xcstrings', json.dumps({'value': fixture}) + '\n')
		result = self.scan()
		self.assertEqual(result.returncode, 1)
		self.assertIn('secret', result.stderr.lower())
		self.assertNotIn(fixture, result.stdout + result.stderr)


if __name__ == '__main__':
	unittest.main()
