#!/usr/bin/env python3
"""About must describe the dependency versions resolved for the shipped application."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DependencyMetadataTests(unittest.TestCase):
	def test_metadata_matches_every_resolved_pin(self):
		pins = json.loads((ROOT / 'AsNeeded.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())['pins']
		source = (ROOT / 'AsNeeded/Services/PackageDependencyManager.swift').read_text()
		entries = {}
		for block in source.split('PackageDependency(')[1:]:
			identity = re.search(r'id: "([^"]+)"', block)
			version = re.search(r'versionInfo: \.(version|branch|revision)\("([^"]+)"\)', block)
			revision = re.search(r'commitHash: "([^"]+)"', block)
			self.assertIsNotNone(identity)
			self.assertIsNotNone(version)
			self.assertIsNotNone(revision)
			entries[identity[1]] = (version[1], version[2], revision[1])
		self.assertEqual(set(entries), {pin['identity'] for pin in pins})
		for pin in pins:
			state = pin['state']
			kind = 'version' if 'version' in state else 'branch' if 'branch' in state else 'revision'
			self.assertEqual(entries[pin['identity']], (kind, state[kind], state['revision']), pin['identity'])


if __name__ == '__main__':
	unittest.main()
