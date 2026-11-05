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
	def run_tests(self, inventory, destination=None):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			commands = {
				"sysctl": "#!/bin/sh\necho 4\n",
				"xcrun": "#!/bin/sh\nprintf '%s' \"$SIMULATOR_INVENTORY\"\n",
				"xcodebuild": "#!/usr/bin/env python3\nimport json, os, sys\nwith open(os.environ['ARGUMENT_LOG'], 'w') as log: json.dump(sys.argv[1:], log)\n",
				"xcsift": "#!/bin/sh\ncat\n",
			}
			for name, content in commands.items():
				path = root / name
				path.write_text(content)
				path.chmod(0o755)
			argument_log = root / "args.json"
			env = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin", ARGUMENT_LOG=str(argument_log), SIMULATOR_INVENTORY=inventory, TEST_WORKERS="2")
			env.pop("TEST_DESTINATION", None)
			if destination:
				env["TEST_DESTINATION"] = destination
			result = subprocess.run(["bash", str(ROOT / "scripts/test-parallel.sh")], env=env, capture_output=True, text=True)
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


if __name__ == "__main__":
	unittest.main()
