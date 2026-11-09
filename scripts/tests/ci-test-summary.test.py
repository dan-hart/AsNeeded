#!/usr/bin/env python3
"""Exercise the CI report with synthetic Xcode outcomes and result bundles."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
STAGES = ("toolchain", "configuration", "simulator", "packages", "build", "key_check", "tests")


class CITestSummaryTests(unittest.TestCase):
	def report(self, *, outcome=None, result=None, unreadable=False):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			tool = root / "xcrun"
			tool.write_text('#!/bin/sh\nif [ "$RESULT_AVAILABLE" = yes ]; then printf "%s" "$RESULT"; else echo "private runner message" >&2; exit 1; fi\n')
			tool.chmod(0o755)
			bundle = root / "Test Results.xcresult"
			if result is not None or unreadable:
				bundle.mkdir()
			output = root / "report.json"
			summary = root / "step-summary.md"
			env = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin", RESULT=json.dumps(result),
				RESULT_AVAILABLE="no" if unreadable else "yes", GITHUB_STEP_SUMMARY=str(summary))
			env.update({f"CI_{stage.upper()}_OUTCOME": "success" for stage in STAGES})
			if outcome:
				stage, status = outcome
				for later in STAGES[STAGES.index(stage) + 1:]:
					env[f"CI_{later.upper()}_OUTCOME"] = "skipped"
				env[f"CI_{stage.upper()}_OUTCOME"] = status
			process = subprocess.run([sys.executable, str(ROOT / "scripts/ci-test-summary.py"), str(bundle), str(output)],
				env=env, text=True, capture_output=True)
			self.assertTrue(output.exists(), process.stderr)
			return process, json.loads(output.read_text()), summary.read_text()

	def test_passing_execution_reports_test_counts(self):
		process, report, _ = self.report(result={"result": "Passed", "totalTestCount": 5, "passedTests": 4,
			"failedTests": 0, "skippedTests": 1, "expectedFailures": 0, "testFailures": []})
		self.assertEqual(process.returncode, 0, process.stderr)
		self.assertEqual(report["status"], "passed")
		self.assertEqual(report["test_counts"]["passed"], 4)

	def test_failing_test_reports_only_source_identifiers_and_counts(self):
		process, report, summary = self.report(outcome=("tests", "failure"), result={
			"result": "Failed", "totalTestCount": 2, "passedTests": 0, "failedTests": 2, "skippedTests": 0,
			"expectedFailures": 0, "testFailures": [
				{"targetName": "AsNeededTests", "testIdentifierString": "RecordingTests/undo(_:)",
					"failureText": "private assertion payload"},
				{"targetName": "AsNeededTests", "testIdentifierString": "RecordingTests/test(\"private argument\")"}],
			"runtimeWarnings": [{"message": "private runner message"}],
			"devicesAndConfigurations": {"identifier": "private device UUID"}})
		self.assertEqual(process.returncode, 0, process.stderr)
		self.assertEqual(report["status"], "test_case_failure")
		self.assertEqual(report["failed_test_identifiers"], ["RecordingTests/undo(_:)"])
		self.assertIn("RecordingTests/undo(_:)", summary)
		self.assertNotIn("private", json.dumps(report) + summary + process.stdout + process.stderr)

	def test_runner_and_build_failures_have_distinct_stages(self):
		for stage, status in (("simulator", "runner_setup_failure"), ("packages", "package_resolution_failure"),
			("build", "build_failure"), ("key_check", "app_configuration_failure")):
			with self.subTest(stage=stage):
				process, report, _ = self.report(outcome=(stage, "failure"))
				self.assertEqual(process.returncode, 0, process.stderr)
				self.assertEqual(report["status"], status)
				self.assertEqual(report["stages"][stage], "failure")
				self.assertEqual(report["result_bundle"], "not_run")

	def test_unreadable_result_cannot_prove_assertion_failure(self):
		process, report, summary = self.report(outcome=("tests", "failure"), unreadable=True)
		self.assertEqual(process.returncode, 0, process.stderr)
		self.assertEqual(report["status"], "test_execution_failure")
		self.assertEqual(report["result_bundle"], "unreadable")
		self.assertNotIn("private", summary + process.stdout + process.stderr)

	def test_nominally_successful_command_without_test_evidence_fails(self):
		process, report, _ = self.report(result={"result": "unknown", "totalTestCount": 0, "passedTests": 0,
			"failedTests": 0, "skippedTests": 0, "expectedFailures": 0, "testFailures": []})
		self.assertNotEqual(process.returncode, 0)
		self.assertEqual(report["status"], "test_evidence_failure")


if __name__ == "__main__":
	unittest.main()
