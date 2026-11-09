#!/usr/bin/env python3
"""Publish CI stage outcomes and an allowlisted subset of xcresult metadata."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

STAGE_FAILURES = {
	"toolchain": "runner_setup_failure",
	"configuration": "app_configuration_failure",
	"simulator": "runner_setup_failure",
	"packages": "package_resolution_failure",
	"build": "build_failure",
	"key_check": "app_configuration_failure",
}
OUTCOMES = {"success", "failure", "skipped", "cancelled"}
COUNT_KEYS = {"total": "totalTestCount", "passed": "passedTests", "failed": "failedTests",
	"skipped": "skippedTests", "expected_failures": "expectedFailures"}
TEST_IDENTIFIER = re.compile(r"(?:[a-zA-Z_][a-zA-Z_0-9.]*/)+[a-zA-Z_][a-zA-Z_0-9]*(?:\((?:[a-zA-Z_][a-zA-Z_0-9]*:)*\))?")


def read_test_result(bundle):
	if not bundle.is_dir():
		return "missing", {}
	try:
		command = ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle)]
		result = json.loads(subprocess.check_output(command, stderr=subprocess.DEVNULL))
	except (OSError, subprocess.CalledProcessError, ValueError):
		return "unreadable", {}
	if not isinstance(result, dict):
		return "unreadable", {}
	return "available", result


def failed_identifiers(result):
	identifiers = set()
	failures = result.get("testFailures")
	for entry in failures if isinstance(failures, list) else []:
		if not isinstance(entry, dict) or entry.get("targetName") != "AsNeededTests":
			continue
		name = entry.get("testIdentifierString")
		if isinstance(name, str) and len(name) <= 200 and TEST_IDENTIFIER.fullmatch(name):
			identifiers.add(name)
	return sorted(identifiers)[:20]


def summarize(bundle):
	stages = {}
	for stage in (*STAGE_FAILURES, "tests"):
		outcome = os.environ.get(f"CI_{stage.upper()}_OUTCOME")
		stages[stage] = outcome if outcome in OUTCOMES else "unknown"

	bundle_status, result = "not_run", {}
	if stages["tests"] in {"success", "failure"}:
		bundle_status, result = read_test_result(bundle)
	counts = {}
	for name, key in COUNT_KEYS.items():
		count = result.get(key)
		if type(count) is int and count >= 0:
			counts[name] = count
	identifiers = failed_identifiers(result)

	status = next((label for stage, label in STAGE_FAILURES.items() if stages[stage] == "failure"), "incomplete")
	if status == "incomplete" and stages["tests"] in {"success", "failure"}:
		if counts.get("failed", 0) > 0:
			status = "test_case_failure"
		elif stages["tests"] == "failure":
			status = "test_execution_failure"
		elif result.get("result") == "Passed" and counts.get("failed") == 0 and counts.get("passed", 0) > 0:
			status = "passed"
		else:
			status = "test_evidence_failure"
	return {"status": status, "stages": stages, "result_bundle": bundle_status,
		"test_counts": counts, "failed_test_identifiers": identifiers}


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("result_bundle", type=Path)
	parser.add_argument("report", type=Path)
	args = parser.parse_args()
	report = summarize(args.result_bundle)
	args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
	if summary_path := os.environ.get("GITHUB_STEP_SUMMARY"):
		with open(summary_path, "a", encoding="utf-8") as summary:
			summary.write(f"## iOS simulator checks\n\nOutcome: `{report['status']}`\n\n")
			for stage, outcome in report["stages"].items():
				summary.write(f"- {stage}: {outcome}\n")
			summary.write(f"\nResult bundle: {report['result_bundle']}\n\n")
			for test, count in report["test_counts"].items():
				summary.write(f"- {test}: {count}\n")
			if report["failed_test_identifiers"]:
				summary.write("\nReported failing tests (up to 20)\n\n")
				for name in report["failed_test_identifiers"]:
					summary.write(f"- `{name}`\n")
	# Earlier workflow step failures already fail the job. Reject a nominal test success without proof.
	return int(report["stages"]["tests"] == "success" and report["status"] != "passed")


if __name__ == "__main__":
	raise SystemExit(main())
