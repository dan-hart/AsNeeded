#!/usr/bin/env python3
"""Deterministic synthetic scanner regressions; no live credentials."""
import base64
import hashlib
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('scanner', Path(__file__).parents[1] / 'utilities/base64-secret-scan.py')
SCANNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SCANNER)


class Base64ScannerTests(unittest.TestCase):
	def test_swift_symbols(self):
		text = 'let icon = SFSafeSymbols.clockArrowTriangleheadCounterclockwiseRotate90\nfunc reconcileScheduledMedicationReminderNotificationRequests() {}\n'
		self.assertEqual(list(SCANNER.findings(text, 'Example.swift')), [])

	def test_path_reference(self):
		path = 'Modules/' + ''.join(('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789AB')) + '.swift'
		self.assertEqual(list(SCANNER.findings(f'Changed `{path}`.', 'notes.md')), [1])
		self.assertEqual(list(SCANNER.findings(f'Changed `{path}`.', 'notes.md', [path])), [])

	def test_recorded_hash(self):
		digest = hashlib.sha256(b'nonsecret artifact').hexdigest()
		for path, text in [('Package.resolved', f'"originHash": "{digest}"'), ('notes.md', f'IPA SHA256: `{digest}`')]:
			self.assertEqual(list(SCANNER.findings(text, path)), [])

	def test_encoded_value(self):
		encoded = base64.b64encode(hashlib.sha512(b'synthetic fixture').digest()).decode()
		for path in ['notes.md', 'Example.swift', 'Watch App/Config.swift']:
			self.assertEqual(list(SCANNER.findings(f'let value = "{encoded}"', path)), [1])

	def test_code_context_only(self):
		# Construct an identifier with enough distinct characters to exceed the entropy threshold.
		name = ''.join(('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789AB'))
		self.assertGreater(SCANNER.entropy(name), 4.5)
		self.assertEqual(list(SCANNER.findings(f'func {name}() {{}}', 'Example.swift')), [])
		self.assertEqual(list(SCANNER.findings(f'let value = "{name}"', 'Example.swift')), [1])
		self.assertEqual(list(SCANNER.findings(f'// func {name}()', 'Example.swift')), [1])
		self.assertEqual(list(SCANNER.findings(f'let value = #"func {name}()"#', 'Example.swift')), [1])

	def test_noncanonical_or_low_entropy(self):
		self.assertFalse(SCANNER.canonical('A' * 45))
		self.assertEqual(list(SCANNER.findings('A' * 64, 'notes.md')), [])

	def test_line_offsets(self):
		name = ''.join(('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789AB'))
		self.assertEqual(list(SCANNER.findings(f'// header\nfunc {name}() {{}}\nlet value = "{name}"\n', 'Example.swift')), [3])


if __name__ == '__main__':
	unittest.main()
