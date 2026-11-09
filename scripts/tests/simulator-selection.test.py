#!/usr/bin/env python3
"""Test simulator selection without accessing CoreSimulator or running Xcode."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SimulatorSelectionTests(unittest.TestCase):
	def run_tests(self, inventory, destination=None, prebuilt=False, status=0, test_filter=None, keyless=False, parallel=None):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			commands = {
				"sysctl": "#!/bin/sh\necho 4\n",
				"xcrun": "#!/bin/sh\nprintf '%s' \"$SIMULATOR_INVENTORY\"\n",
				"xcodebuild": "#!/usr/bin/env python3\nimport json, os, sys\nwith open(os.environ['ARGUMENT_LOG'], 'w') as log: json.dump(sys.argv[1:], log)\nsys.exit(int(os.environ['TEST_EXIT']))\n",
				"xcsift": "#!/bin/sh\ncat\n",
			}
			for name, content in commands.items():
				path = root / name
				path.write_text(content)
				path.chmod(0o755)
			argument_log = root / "args.json"
			env = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin", ARGUMENT_LOG=str(argument_log), SIMULATOR_INVENTORY=inventory, TEST_WORKERS="2", TEST_EXIT=str(status))
			for setting in ("TEST_DESTINATION", "TEST_WITHOUT_BUILDING", "TEST_DERIVED_DATA_PATH", "TEST_PINNED_PACKAGES_PATH", "TEST_RESULT_BUNDLE_PATH", "TEST_DISABLE_REVENUECAT", "TEST_PARALLEL_ENABLED", "TEST_RAW_OUTPUT"):
				env.pop(setting, None)
			if destination:
				env["TEST_DESTINATION"] = destination
			if prebuilt:
				env.update(TEST_WITHOUT_BUILDING="1", TEST_DERIVED_DATA_PATH=str(root / "Derived Data"),
					TEST_PINNED_PACKAGES_PATH=str(root / "Pinned Packages"), TEST_RESULT_BUNDLE_PATH=str(root / "Test Results.xcresult"))
			if keyless:
				env["TEST_DISABLE_REVENUECAT"] = "1"
			if parallel is not None:
				env["TEST_PARALLEL_ENABLED"] = parallel
			command = ["bash", str(ROOT / "scripts/test-parallel.sh")]
			if test_filter:
				command.append(test_filter)
			result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True)
			args = json.loads(argument_log.read_text()) if argument_log.exists() else None
			return result, args

	def test_selects_available_iphone_and_preserves_workers(self):
		inventory = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
			{"name": "iPhone unavailable", "isAvailable": False, "udid": "skip"},
			{"name": "iPad", "isAvailable": True, "udid": "skip-tablet"},
			{"name": "iPhone installed", "isAvailable": True, "udid": "synthetic-uuid"},
		]}}
		result, args = self.run_tests(json.dumps(inventory))
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[args.index("-destination") + 1], "platform=iOS Simulator,id=synthetic-uuid")
		self.assertEqual(args[args.index("-maximum-parallel-testing-workers") + 1], "2")

	def run_ci_selector(self, inventory):
		workflow = (ROOT / ".github/workflows/build.yml").read_text()
		script = workflow.split("          python3 - <<'PYTHON'\n", 1)[1].split("          PYTHON", 1)[0]
		script = "\n".join(line[10:] if line.startswith("          ") else line for line in script.splitlines())
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "simulators.json").write_text(json.dumps(inventory))
			output = root / "environment"
			result = subprocess.run(["python3", "-c", script], cwd=ROOT, env=dict(os.environ, RUNNER_TEMP=directory, GITHUB_ENV=str(output)), capture_output=True, text=True)
			return result, output.read_text() if output.exists() else ""

	def test_older_runtime_before_compatible_runtime_is_skipped(self):
		inventory = {"devices": {
			"com.apple.CoreSimulator.SimRuntime.iOS-18-5": [{"name": "iPhone old", "isAvailable": True, "udid": "too-old"}],
			"com.apple.CoreSimulator.SimRuntime.iOS-26-0": [{"name": "iPhone compatible", "isAvailable": True, "udid": "compatible"}],
		}}
		result, args = self.run_tests(json.dumps(inventory))
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[args.index("-destination") + 1], "platform=iOS Simulator,id=compatible")

	def test_ci_skips_older_runtime(self):
		inventory = {"devices": {
			"com.apple.CoreSimulator.SimRuntime.iOS-18-5": [{"name": "iPhone old", "isAvailable": True, "udid": "too-old"}],
			"com.apple.CoreSimulator.SimRuntime.iOS-26-0": [{"name": "iPhone compatible", "isAvailable": True, "udid": "compatible"}],
		}}
		result, output = self.run_ci_selector(inventory)
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertIn("id=compatible", output)

	def test_too_old_only_stops_before_xcodebuild(self):
		inventory = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-18-5": [{"name": "iPhone old", "isAvailable": True, "udid": "too-old"}]}}
		result, args = self.run_tests(json.dumps(inventory))
		self.assertNotEqual(result.returncode, 0)
		self.assertIsNone(args)
		self.assertIn("TEST_DESTINATION", result.stderr)

	def test_ci_rejects_too_old_only(self):
		inventory = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-18-5": [{"name": "iPhone old", "isAvailable": True, "udid": "too-old"}]}}
		result, output = self.run_ci_selector(inventory)
		self.assertNotEqual(result.returncode, 0)
		self.assertEqual(output, "")

	def test_no_available_iphone_fails_before_xcodebuild(self):
		result, args = self.run_tests('{"devices": {}}')
		self.assertNotEqual(result.returncode, 0)
		self.assertIsNone(args)
		self.assertIn("TEST_DESTINATION", result.stderr)

	def test_invalid_inventory_fails_before_xcodebuild(self):
		result, args = self.run_tests("invalid JSON")
		self.assertNotEqual(result.returncode, 0)
		self.assertIsNone(args)
		self.assertIn("simulator", result.stderr.lower())

	def test_explicit_destination_bypasses_inventory(self):
		destination = "platform=iOS Simulator,id=override-uuid"
		result, args = self.run_tests("invalid JSON", destination)
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[args.index("-destination") + 1], destination)
		self.assertEqual(args[0], "test")

	def test_prebuilt_execution_keeps_full_suite_and_explicit_bundle(self):
		result, args = self.run_tests("invalid JSON", "platform=iOS Simulator,id=prebuilt", prebuilt=True)
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[0], "test-without-building")
		self.assertTrue(args[args.index("-derivedDataPath") + 1].endswith("/Derived Data"))
		self.assertTrue(args[args.index("-clonedSourcePackagesDirPath") + 1].endswith("/Pinned Packages"))
		self.assertTrue(args[args.index("-resultBundlePath") + 1].endswith("/Test Results.xcresult"))
		self.assertIn("-onlyUsePackageVersionsFromResolvedFile", args)
		self.assertFalse(any(arg.startswith("-only-testing:") for arg in args))

	def test_handoff_can_run_keyless_without_changing_other_test_invocations(self):
		for keyless in (True, False):
			with self.subTest(keyless=keyless):
				result, args = self.run_tests("invalid JSON", "platform=iOS Simulator,id=synthetic", keyless=keyless)
				self.assertEqual(result.returncode, 0, result.stderr)
				self.assertEqual("REVENUECAT_API_KEY=" in args, keyless)

	def test_serial_execution_keeps_the_full_suite(self):
		result, args = self.run_tests("invalid JSON", "platform=iOS Simulator,id=synthetic", parallel="NO")
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[args.index("-parallel-testing-enabled") + 1], "NO")
		self.assertFalse(any(arg.startswith("-only-testing:") for arg in args))

	def test_formatter_cannot_hide_test_failure(self):
		result, args = self.run_tests("invalid JSON", "platform=iOS Simulator,id=prebuilt", status=65, test_filter="RecordingTests")
		self.assertEqual(result.returncode, 65, result.stdout)
		self.assertIn("-only-testing:AsNeededTests/RecordingTests", args)
		self.assertNotIn("All tests passed", result.stdout)


if __name__ == "__main__":
	unittest.main()
