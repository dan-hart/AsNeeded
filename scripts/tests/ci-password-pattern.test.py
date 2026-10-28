#!/usr/bin/env python3
"""Check the actual hosted password-assignment expression using synthetic data."""
import ast
from pathlib import Path
import subprocess
import unittest

WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/security-scan.yml'
PATTERN = ast.literal_eval(next(line.strip() for line in WORKFLOW.read_text().splitlines()
	if line.strip().startswith('"(^|[[:space:]') and 'password' in line))


class HostedPatternTests(unittest.TestCase):
	def matches(self, text):
		return subprocess.run(['grep', '-E', '-i', PATTERN], input=text, text=True, capture_output=True).returncode == 0

	def test_ui_binding_is_not_a_credential(self):
		self.assertFalse(self.matches('SecureField("Password", text: $viewModel.password)'))

	def test_input_properties_are_not_credentials(self):
		self.assertFalse(self.matches('autoComplete="current-password"; textContentType="password"'))

	def test_prose_is_not_an_assignment(self):
		self.assertFalse(self.matches('Its password was unrelated. The next attempt failed: another dialog appeared.'))

	def test_real_assignment_shapes_are_detected(self):
		name = 'pass' + 'word'
		value = 'synthetic' + 'X' * 24
		for field in [name, 'config.' + name, 'settings.auth.' + name, 'DB_' + name.upper(), 'account' + name.title()]:
			for text in [field + ': ' + value, field + ' = "' + value + '"', '"' + field + '": "' + value + '"']:
				self.assertTrue(self.matches(text), field)


if __name__ == '__main__':
	unittest.main()
