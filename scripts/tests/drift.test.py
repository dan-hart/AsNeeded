"""Verify Drift freshness behavior and business rule traceability."""
import json
from pathlib import Path
import re
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

	def test_every_business_rule_has_bound_implementation_and_regression_evidence(self):
		root = Path(__file__).resolve().parents[2]
		rules_file = "BUSINESS_RULES.md"
		document = (root / rules_file).read_text()
		rule_ids = re.findall(r"^\*\*([A-Z]+-\d+) —", document, re.MULTILINE)
		rows = re.findall(r"^\| \[([A-Z]+-\d+)\]\(#([a-z]+-\d+)\) \| ([^|]+) \| ([^|]+) \|$", document, re.MULTILINE)
		self.assertTrue(rule_ids, "No business rules found")
		self.assertCountEqual([rule for rule, *_ in rows], rule_ids)
		self.assertEqual(len(rule_ids), len(set(rule_ids)), "Duplicate business rule ID")

		status = subprocess.run(["drift", "status", "--format", "json"], cwd=root, check=True, capture_output=True, text=True)
		bindings = {entry["doc"]: set(entry["files"]) for entry in json.loads(status.stdout)}
		anchors = bindings.get(rules_file, set())
		for rule, fragment, implementation, evidence in rows:
			with self.subTest(rule=rule):
				self.assertEqual(fragment, rule.lower())
				self.assertIn(f'<a id="{fragment}"></a>', document)
				for column, cell in (("implementation", implementation), ("regression evidence", evidence)):
					paths = {path.removeprefix("<").removesuffix(">") for path in re.findall(r"\]\(([^)#]+)\)", cell)}
					self.assertTrue(paths, f"{rule} has no {column} links")
					unbound = paths - anchors
					self.assertFalse(unbound, f"{rule} {column} missing Drift bindings: {', '.join(sorted(unbound))}")


if __name__ == "__main__":
	unittest.main()
