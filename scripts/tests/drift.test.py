"""Exercise the optional Drift checker against isolated Swift/document fixtures."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(shutil.which("drift"), "Drift is optional locally; the dedicated CI job installs it")
class DriftFreshnessTests(unittest.TestCase):
	def test_source_change_requires_document_review_without_refreshing_lock(self):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "rules.md").write_text("# Recording rule\n\nUse the recorded timestamp.\n")
			source = root / "DoseRule.swift"
			source.write_text("struct DoseRule { let usesRecordedTime = true }\n")
			subprocess.run(["drift", "link", "rules.md", "DoseRule.swift"], cwd=root, check=True, capture_output=True)
			lock = (root / "drift.lock").read_bytes()
			fresh = subprocess.run(["drift", "check", "--format", "json"], cwd=root, capture_output=True, text=True)
			self.assertEqual(fresh.returncode, 0, fresh.stderr)
			self.assertEqual(json.loads(fresh.stdout)["summary"]["docs_fresh"], 1)
			source.write_text("struct DoseRule { let usesRecordedTime = false }\n")
			stale = subprocess.run(["drift", "check", "--format", "json"], cwd=root, capture_output=True, text=True)
			self.assertEqual(stale.returncode, 1, stale.stderr)
			self.assertEqual(json.loads(stale.stdout)["summary"]["docs_stale"], 1)
			self.assertEqual((root / "drift.lock").read_bytes(), lock)


if __name__ == "__main__":
	unittest.main()
